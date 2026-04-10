use rustler::{Binary, OwnedBinary, ResourceArc};
use rustc_hash::{FxHashMap, FxHashSet};
use std::collections::HashMap;

// ---------------------------------------------------------------------------
// Resource: lock-free immutable storage
// ---------------------------------------------------------------------------

pub struct VecResource(Box<[i64]>);

// SAFETY: Box<[i64]> is Send + Sync since i64 is. The contents are immutable
// after construction — we never hand out &mut references to the inner slice.
unsafe impl Send for VecResource {}
unsafe impl Sync for VecResource {}

#[rustler::resource_impl]
impl rustler::Resource for VecResource {}

#[inline(always)]
fn as_slice(resource: &ResourceArc<VecResource>) -> &[i64] {
    &resource.0
}

#[inline(always)]
fn wrap(vec: Vec<i64>) -> ResourceArc<VecResource> {
    ResourceArc::new(VecResource(vec.into_boxed_slice()))
}

#[inline(always)]
fn wrap_slice(slice: &[i64]) -> ResourceArc<VecResource> {
    ResourceArc::new(VecResource(slice.into()))
}

// ---------------------------------------------------------------------------
// Binary helpers
// ---------------------------------------------------------------------------

const I64_SIZE: usize = std::mem::size_of::<i64>();

/// Reinterpret binary bytes as &[i64] — zero copy.
/// Must be a macro because Binary's dual lifetimes prevent returning a
/// borrow from a helper function when the Binary is an owned NIF parameter.
macro_rules! as_i64_slice {
    ($binary:expr) => {{
        let data = $binary.as_slice();
        let n = data.len() / I64_SIZE;
        if n == 0 {
            &[] as &[i64]
        } else {
            unsafe { std::slice::from_raw_parts(data.as_ptr() as *const i64, n) }
        }
    }};
}

/// Copy binary bytes into a Vec<i64>.
#[inline]
fn binary_to_vec(binary: &Binary) -> Vec<i64> {
    let data = binary.as_slice();
    let n = data.len() / I64_SIZE;
    let mut vec = Vec::with_capacity(n);
    if n > 0 {
        unsafe {
            std::ptr::copy_nonoverlapping(data.as_ptr() as *const i64, vec.as_mut_ptr(), n);
            vec.set_len(n);
        }
    }
    vec
}

/// Write a &[i64] slice into a new OwnedBinary.
#[inline]
fn slice_to_binary(slice: &[i64]) -> OwnedBinary {
    let byte_len = slice.len() * I64_SIZE;
    let mut owned = OwnedBinary::new(byte_len).unwrap();
    if byte_len > 0 {
        unsafe {
            std::ptr::copy_nonoverlapping(
                slice.as_ptr() as *const u8,
                owned.as_mut_slice().as_mut_ptr(),
                byte_len,
            );
        }
    }
    owned
}

/// Safe in-place: copy binary into OwnedBinary, return (owned, num_elements).
#[inline]
fn safe_copy(binary: &Binary) -> (OwnedBinary, usize) {
    let data = binary.as_slice();
    let n = data.len() / I64_SIZE;
    let mut owned = OwnedBinary::new(data.len()).unwrap();
    if !data.is_empty() {
        unsafe {
            std::ptr::copy_nonoverlapping(
                data.as_ptr(),
                owned.as_mut_slice().as_mut_ptr(),
                data.len(),
            );
        }
    }
    (owned, n)
}

/// Reinterpret OwnedBinary bytes as &mut [i64].
#[inline(always)]
fn owned_as_mut_slice(owned: &mut OwnedBinary, n: usize) -> &mut [i64] {
    unsafe {
        std::slice::from_raw_parts_mut(owned.as_mut_slice().as_mut_ptr() as *mut i64, n)
    }
}

/// Single-pass min and max over a slice.
#[inline]
fn minmax(slice: &[i64]) -> Option<(i64, i64)> {
    let (&first, rest) = slice.split_first()?;
    let mut lo = first;
    let mut hi = first;
    for &v in rest {
        if v < lo { lo = v; }
        else if v > hi { hi = v; }
    }
    Some((lo, hi))
}

/// Build a frequency map using FxHash (fast integer hashing), then convert
/// to std HashMap for Rustler encoding (Rustler implements Encoder for std HashMap).
#[inline]
fn frequencies_impl(slice: &[i64]) -> HashMap<i64, usize> {
    let mut map: FxHashMap<i64, usize> = FxHashMap::with_capacity_and_hasher(
        slice.len() / 4,
        Default::default(),
    );
    for &v in slice {
        *map.entry(v).or_insert(0) += 1;
    }
    // Convert to std HashMap for Rustler encoding
    map.into_iter().collect()
}

/// Fast i64 to string using itoa, write into a String buffer.
#[inline]
fn join_impl(slice: &[i64], separator: &str) -> String {
    if slice.is_empty() {
        return String::new();
    }
    // Estimate: ~6 chars per number + separator
    let mut result = String::with_capacity(slice.len() * (6 + separator.len()));
    let mut buf = itoa::Buffer::new();
    result.push_str(buf.format(slice[0]));
    for &v in &slice[1..] {
        result.push_str(separator);
        result.push_str(buf.format(v));
    }
    result
}

// ---------------------------------------------------------------------------
// Foundation
// ---------------------------------------------------------------------------

#[rustler::nif]
fn nif_new(list: Vec<i64>) -> ResourceArc<VecResource> { wrap(list) }

#[rustler::nif]
fn nif_new_from_binary(binary: Binary) -> ResourceArc<VecResource> {
    wrap(binary_to_vec(&binary))
}

#[rustler::nif]
fn nif_to_list(resource: ResourceArc<VecResource>) -> Vec<i64> {
    as_slice(&resource).to_vec()
}

#[rustler::nif]
fn nif_to_binary(resource: ResourceArc<VecResource>) -> OwnedBinary {
    slice_to_binary(as_slice(&resource))
}

#[rustler::nif]
fn nif_length(resource: ResourceArc<VecResource>) -> usize {
    resource.0.len()
}

#[rustler::nif]
fn nif_inspect(resource: ResourceArc<VecResource>, count: usize) -> Vec<i64> {
    let s = as_slice(&resource);
    let n = std::cmp::min(count, s.len());
    s[..n].to_vec()
}

// ---------------------------------------------------------------------------
// Tier 1: Ordering — Resource (chain)
// ---------------------------------------------------------------------------

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_sort_asc(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let mut vec = as_slice(&resource).to_vec();
    vec.sort_unstable();
    wrap(vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_sort_desc(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let mut vec = as_slice(&resource).to_vec();
    vec.sort_unstable_by(|a, b| b.cmp(a));
    wrap(vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_reverse(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let mut vec = as_slice(&resource).to_vec();  // memcpy (sequential, prefetcher-friendly)
    vec.reverse();  // in-place swap loop (sequential from both ends)
    wrap(vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_dedup(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let s = as_slice(&resource);
    if s.is_empty() { return wrap(Vec::new()); }
    let mut result = Vec::with_capacity(s.len());
    let mut prev = s[0];
    result.push(prev);
    for &v in &s[1..] {
        if v != prev {
            result.push(v);
            prev = v;
        }
    }
    wrap(result)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_uniq(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let s = as_slice(&resource);
    let mut seen = FxHashSet::with_capacity_and_hasher(s.len() / 2, Default::default());
    let result: Vec<i64> = s.iter().copied().filter(|x| seen.insert(*x)).collect();
    wrap(result)
}

// ---------------------------------------------------------------------------
// Tier 1: Ordering — Binary (one-shot, safe in-place copy)
// ---------------------------------------------------------------------------

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_sort_asc_binary(binary: Binary) -> OwnedBinary {
    let (mut owned, n) = safe_copy(&binary);
    owned_as_mut_slice(&mut owned, n).sort_unstable();
    owned
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_sort_desc_binary(binary: Binary) -> OwnedBinary {
    let (mut owned, n) = safe_copy(&binary);
    owned_as_mut_slice(&mut owned, n).sort_unstable_by(|a, b| b.cmp(a));
    owned
}

/// memcpy + in-place reverse: both passes are sequential (prefetcher-friendly).
/// Faster than reading source backwards which causes cache misses on large arrays.
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_reverse_binary(binary: Binary) -> OwnedBinary {
    let (mut owned, n) = safe_copy(&binary);
    if n > 1 {
        owned_as_mut_slice(&mut owned, n).reverse();
    }
    owned
}

/// Single-pass dedup: scan source, write non-duplicates directly to output binary.
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_dedup_binary(binary: Binary) -> OwnedBinary {
    let src = as_i64_slice!(binary);
    if src.is_empty() {
        return OwnedBinary::new(0).unwrap();
    }
    // Worst case: no duplicates, same size as input
    let mut result = Vec::with_capacity(src.len());
    let mut prev = src[0];
    result.push(prev);
    for &v in &src[1..] {
        if v != prev {
            result.push(v);
            prev = v;
        }
    }
    slice_to_binary(&result)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_uniq_binary(binary: Binary) -> OwnedBinary {
    let slice = as_i64_slice!(binary);
    let mut seen = FxHashSet::with_capacity_and_hasher(slice.len() / 2, Default::default());
    let result: Vec<i64> = slice.iter().copied().filter(|x| seen.insert(*x)).collect();
    slice_to_binary(&result)
}

// ---------------------------------------------------------------------------
// Tier 1: Aggregation — Resource (chain)
// ---------------------------------------------------------------------------

#[rustler::nif]
fn nif_sum(resource: ResourceArc<VecResource>) -> i64 {
    as_slice(&resource).iter().copied().fold(0i64, |a, b| a.wrapping_add(b))
}

#[rustler::nif]
fn nif_product(resource: ResourceArc<VecResource>) -> i64 {
    as_slice(&resource).iter().copied().fold(1i64, |a, b| a.wrapping_mul(b))
}

#[rustler::nif]
fn nif_min(resource: ResourceArc<VecResource>) -> Option<i64> {
    as_slice(&resource).iter().copied().min()
}

#[rustler::nif]
fn nif_max(resource: ResourceArc<VecResource>) -> Option<i64> {
    as_slice(&resource).iter().copied().max()
}

#[rustler::nif]
fn nif_min_max(resource: ResourceArc<VecResource>) -> Option<(i64, i64)> {
    minmax(as_slice(&resource))
}

#[rustler::nif]
fn nif_count(resource: ResourceArc<VecResource>) -> usize {
    resource.0.len()
}

// ---------------------------------------------------------------------------
// Tier 1: Aggregation — Binary (one-shot, zero-copy read)
// ---------------------------------------------------------------------------

#[rustler::nif]
fn nif_sum_binary(binary: Binary) -> i64 {
    as_i64_slice!(binary).iter().copied().fold(0i64, |a, b| a.wrapping_add(b))
}

#[rustler::nif]
fn nif_product_binary(binary: Binary) -> i64 {
    as_i64_slice!(binary).iter().copied().fold(1i64, |a, b| a.wrapping_mul(b))
}

#[rustler::nif]
fn nif_min_binary(binary: Binary) -> Option<i64> {
    as_i64_slice!(binary).iter().copied().min()
}

#[rustler::nif]
fn nif_max_binary(binary: Binary) -> Option<i64> {
    as_i64_slice!(binary).iter().copied().max()
}

#[rustler::nif]
fn nif_min_max_binary(binary: Binary) -> Option<(i64, i64)> {
    minmax(as_i64_slice!(binary))
}

#[rustler::nif]
fn nif_count_binary(binary: Binary) -> usize {
    binary.as_slice().len() / I64_SIZE
}

// ---------------------------------------------------------------------------
// Tier 1: Access — Resource (chain)
// ---------------------------------------------------------------------------

#[rustler::nif]
fn nif_at(resource: ResourceArc<VecResource>, index: i64) -> Option<i64> {
    let s = as_slice(&resource);
    let len = s.len() as i64;
    let actual = if index < 0 { len + index } else { index };
    if actual < 0 || actual >= len { None } else { unsafe { Some(*s.get_unchecked(actual as usize)) } }
}

#[rustler::nif]
fn nif_slice(resource: ResourceArc<VecResource>, start: usize, len: usize) -> ResourceArc<VecResource> {
    let s = as_slice(&resource);
    let start = std::cmp::min(start, s.len());
    let end = std::cmp::min(start + len, s.len());
    wrap_slice(&s[start..end])
}

#[rustler::nif]
fn nif_take(resource: ResourceArc<VecResource>, count: i64) -> ResourceArc<VecResource> {
    let s = as_slice(&resource);
    if count >= 0 {
        let n = std::cmp::min(count as usize, s.len());
        wrap_slice(&s[..n])
    } else {
        let n = std::cmp::min((-count) as usize, s.len());
        wrap_slice(&s[s.len() - n..])
    }
}

#[rustler::nif]
fn nif_drop(resource: ResourceArc<VecResource>, count: i64) -> ResourceArc<VecResource> {
    let s = as_slice(&resource);
    if count >= 0 {
        let n = std::cmp::min(count as usize, s.len());
        wrap_slice(&s[n..])
    } else {
        let n = std::cmp::min((-count) as usize, s.len());
        wrap_slice(&s[..s.len() - n])
    }
}

#[rustler::nif]
fn nif_member(resource: ResourceArc<VecResource>, value: i64) -> bool {
    as_slice(&resource).contains(&value)
}

// ---------------------------------------------------------------------------
// Tier 1: Access — Binary (one-shot, zero-copy read)
// ---------------------------------------------------------------------------

#[rustler::nif]
fn nif_at_binary(binary: Binary, index: i64) -> Option<i64> {
    let s = as_i64_slice!(binary);
    let len = s.len() as i64;
    let actual = if index < 0 { len + index } else { index };
    if actual < 0 || actual >= len { None } else { unsafe { Some(*s.get_unchecked(actual as usize)) } }
}

#[rustler::nif]
fn nif_slice_binary(binary: Binary, start: usize, len: usize) -> OwnedBinary {
    let s = as_i64_slice!(binary);
    let start = std::cmp::min(start, s.len());
    let end = std::cmp::min(start + len, s.len());
    slice_to_binary(&s[start..end])
}

#[rustler::nif]
fn nif_take_binary(binary: Binary, count: i64) -> OwnedBinary {
    let s = as_i64_slice!(binary);
    if count >= 0 {
        let n = std::cmp::min(count as usize, s.len());
        slice_to_binary(&s[..n])
    } else {
        let n = std::cmp::min((-count) as usize, s.len());
        slice_to_binary(&s[s.len() - n..])
    }
}

#[rustler::nif]
fn nif_drop_binary(binary: Binary, count: i64) -> OwnedBinary {
    let s = as_i64_slice!(binary);
    if count >= 0 {
        let n = std::cmp::min(count as usize, s.len());
        slice_to_binary(&s[n..])
    } else {
        let n = std::cmp::min((-count) as usize, s.len());
        slice_to_binary(&s[..s.len() - n])
    }
}

#[rustler::nif]
fn nif_member_binary(binary: Binary, value: i64) -> bool {
    as_i64_slice!(binary).contains(&value)
}

// ---------------------------------------------------------------------------
// Tier 1: Combination — Resource (chain)
// ---------------------------------------------------------------------------

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_concat(resource: ResourceArc<VecResource>, other: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let s1 = as_slice(&resource);
    let s2 = as_slice(&other);
    let mut vec = Vec::with_capacity(s1.len() + s2.len());
    vec.extend_from_slice(s1);
    vec.extend_from_slice(s2);
    wrap(vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_frequencies(resource: ResourceArc<VecResource>) -> HashMap<i64, usize> {
    frequencies_impl(as_slice(&resource))
}

#[rustler::nif]
fn nif_empty(resource: ResourceArc<VecResource>) -> bool {
    resource.0.is_empty()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_join(resource: ResourceArc<VecResource>, separator: String) -> String {
    join_impl(as_slice(&resource), &separator)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_with_index(resource: ResourceArc<VecResource>, offset: i64) -> Vec<(i64, i64)> {
    let s = as_slice(&resource);
    let n = s.len();
    let mut result = Vec::with_capacity(n);
    unsafe {
        let ptr: *mut (i64, i64) = result.as_mut_ptr();
        for i in 0..n {
            ptr.add(i).write((*s.get_unchecked(i), i as i64 + offset));
        }
        result.set_len(n);
    }
    result
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_zip(res1: ResourceArc<VecResource>, res2: ResourceArc<VecResource>) -> Vec<(i64, i64)> {
    let s1 = as_slice(&res1);
    let s2 = as_slice(&res2);
    let n = std::cmp::min(s1.len(), s2.len());
    let mut result = Vec::with_capacity(n);
    unsafe {
        let ptr: *mut (i64, i64) = result.as_mut_ptr();
        for i in 0..n {
            ptr.add(i).write((*s1.get_unchecked(i), *s2.get_unchecked(i)));
        }
        result.set_len(n);
    }
    result
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_chunk_every(resource: ResourceArc<VecResource>, count: usize) -> Vec<Vec<i64>> {
    let s = as_slice(&resource);
    s.chunks(count).map(|c: &[i64]| c.to_vec()).collect()
}

// ---------------------------------------------------------------------------
// Tier 1: Combination — Binary (one-shot)
// ---------------------------------------------------------------------------

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_concat_binary(binary1: Binary, binary2: Binary) -> OwnedBinary {
    let s1 = binary1.as_slice();
    let s2 = binary2.as_slice();
    let mut owned = OwnedBinary::new(s1.len() + s2.len()).unwrap();
    let out = owned.as_mut_slice();
    unsafe {
        std::ptr::copy_nonoverlapping(s1.as_ptr(), out.as_mut_ptr(), s1.len());
        std::ptr::copy_nonoverlapping(s2.as_ptr(), out.as_mut_ptr().add(s1.len()), s2.len());
    }
    owned
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_frequencies_binary(binary: Binary) -> HashMap<i64, usize> {
    frequencies_impl(as_i64_slice!(binary))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_join_binary(binary: Binary, separator: String) -> String {
    join_impl(as_i64_slice!(binary), &separator)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_with_index_binary(binary: Binary, offset: i64) -> Vec<(i64, i64)> {
    let s = as_i64_slice!(binary);
    let n = s.len();
    let mut result = Vec::with_capacity(n);
    unsafe {
        let ptr: *mut (i64, i64) = result.as_mut_ptr();
        for i in 0..n {
            ptr.add(i).write((*s.get_unchecked(i), i as i64 + offset));
        }
        result.set_len(n);
    }
    result
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_zip_binary(binary1: Binary, binary2: Binary) -> Vec<(i64, i64)> {
    let s1 = as_i64_slice!(binary1);
    let s2 = as_i64_slice!(binary2);
    let n = std::cmp::min(s1.len(), s2.len());
    let mut result = Vec::with_capacity(n);
    unsafe {
        let ptr: *mut (i64, i64) = result.as_mut_ptr();
        for i in 0..n {
            ptr.add(i).write((*s1.get_unchecked(i), *s2.get_unchecked(i)));
        }
        result.set_len(n);
    }
    result
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_chunk_every_binary(binary: Binary, count: usize) -> Vec<Vec<i64>> {
    let s = as_i64_slice!(binary);
    s.chunks(count).map(|c: &[i64]| c.to_vec()).collect()
}

// ---------------------------------------------------------------------------
// Legacy list-protocol NIFs (kept for sort/uniq/frequencies where NIF wins)
// ---------------------------------------------------------------------------

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_sort_asc_list(list: Vec<i64>) -> Vec<i64> { let mut v = list; v.sort_unstable(); v }
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_sort_desc_list(list: Vec<i64>) -> Vec<i64> { let mut v = list; v.sort_unstable_by(|a, b| b.cmp(a)); v }
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_reverse_list(list: Vec<i64>) -> Vec<i64> { let mut v = list; v.reverse(); v }
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_dedup_list(list: Vec<i64>) -> Vec<i64> { let mut v = list; v.dedup(); v }
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_uniq_list(list: Vec<i64>) -> Vec<i64> {
    let cap = list.len() / 2;
    let mut seen = FxHashSet::with_capacity_and_hasher(cap, Default::default());
    list.into_iter().filter(|x| seen.insert(*x)).collect()
}
#[rustler::nif]
fn nif_sum_list(list: Vec<i64>) -> i64 { list.iter().copied().fold(0i64, |a, b| a.wrapping_add(b)) }
#[rustler::nif]
fn nif_product_list(list: Vec<i64>) -> i64 { list.iter().copied().fold(1i64, |a, b| a.wrapping_mul(b)) }
#[rustler::nif]
fn nif_min_list(list: Vec<i64>) -> Option<i64> { list.iter().copied().min() }
#[rustler::nif]
fn nif_max_list(list: Vec<i64>) -> Option<i64> { list.iter().copied().max() }
#[rustler::nif]
fn nif_min_max_list(list: Vec<i64>) -> Option<(i64, i64)> { minmax(&list) }
#[rustler::nif]
fn nif_count_list(list: Vec<i64>) -> usize { list.len() }
#[rustler::nif]
fn nif_at_list(list: Vec<i64>, index: i64) -> Option<i64> {
    let len = list.len() as i64;
    let actual = if index < 0 { len + index } else { index };
    if actual < 0 || actual >= len { None } else { unsafe { Some(*list.get_unchecked(actual as usize)) } }
}
#[rustler::nif]
fn nif_slice_list(list: Vec<i64>, start: usize, len: usize) -> Vec<i64> {
    let start = std::cmp::min(start, list.len());
    let end = std::cmp::min(start + len, list.len());
    list[start..end].to_vec()
}
#[rustler::nif]
fn nif_take_list(list: Vec<i64>, count: i64) -> Vec<i64> {
    if count >= 0 { let n = std::cmp::min(count as usize, list.len()); list[..n].to_vec() }
    else { let n = std::cmp::min((-count) as usize, list.len()); list[list.len() - n..].to_vec() }
}
#[rustler::nif]
fn nif_drop_list(list: Vec<i64>, count: i64) -> Vec<i64> {
    if count >= 0 { let n = std::cmp::min(count as usize, list.len()); list[n..].to_vec() }
    else { let n = std::cmp::min((-count) as usize, list.len()); list[..list.len() - n].to_vec() }
}
#[rustler::nif]
fn nif_member_list(list: Vec<i64>, value: i64) -> bool { list.contains(&value) }
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_concat_list(list1: Vec<i64>, list2: Vec<i64>) -> Vec<i64> {
    let mut r = Vec::with_capacity(list1.len() + list2.len());
    r.extend_from_slice(&list1);
    r.extend_from_slice(&list2);
    r
}
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_frequencies_list(list: Vec<i64>) -> HashMap<i64, usize> {
    frequencies_impl(&list)
}
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_join_list(list: Vec<i64>, separator: String) -> String {
    join_impl(&list, &separator)
}
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_with_index_list(list: Vec<i64>, offset: i64) -> Vec<(i64, i64)> {
    let n = list.len();
    let mut result = Vec::with_capacity(n);
    unsafe {
        let ptr: *mut (i64, i64) = result.as_mut_ptr();
        for i in 0..n {
            ptr.add(i).write((*list.get_unchecked(i), i as i64 + offset));
        }
        result.set_len(n);
    }
    result
}
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_zip_list(list1: Vec<i64>, list2: Vec<i64>) -> Vec<(i64, i64)> {
    let n = std::cmp::min(list1.len(), list2.len());
    let mut result = Vec::with_capacity(n);
    unsafe {
        let ptr: *mut (i64, i64) = result.as_mut_ptr();
        for i in 0..n {
            ptr.add(i).write((*list1.get_unchecked(i), *list2.get_unchecked(i)));
        }
        result.set_len(n);
    }
    result
}
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_chunk_every_list(list: Vec<i64>, count: usize) -> Vec<Vec<i64>> {
    list.chunks(count).map(|c: &[i64]| c.to_vec()).collect()
}

rustler::init!("Elixir.FEnum.Native");
