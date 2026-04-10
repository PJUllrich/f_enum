use rustler::{Binary, OwnedBinary, ResourceArc};
use std::collections::HashMap;
use std::sync::RwLock;

#[derive(Debug)]
pub struct VecResource(pub RwLock<Vec<i64>>);

#[rustler::resource_impl]
impl rustler::Resource for VecResource {}

fn read_vec(resource: &ResourceArc<VecResource>) -> Vec<i64> {
    resource.0.read().unwrap().clone()
}

fn wrap(vec: Vec<i64>) -> ResourceArc<VecResource> {
    ResourceArc::new(VecResource(RwLock::new(vec)))
}

// ---------------------------------------------------------------------------
// Binary helpers
// ---------------------------------------------------------------------------

const I64_SIZE: usize = std::mem::size_of::<i64>();

/// Copy binary bytes into a Vec<i64>.
fn binary_to_vec(binary: &Binary) -> Vec<i64> {
    let data = binary.as_slice();
    let num_elements = data.len() / I64_SIZE;
    let mut vec = Vec::with_capacity(num_elements);
    unsafe {
        std::ptr::copy_nonoverlapping(
            data.as_ptr() as *const i64,
            vec.as_mut_ptr(),
            num_elements,
        );
        vec.set_len(num_elements);
    }
    vec
}

/// Write a &[i64] slice into a new OwnedBinary.
fn slice_to_binary(slice: &[i64]) -> OwnedBinary {
    let byte_len = slice.len() * I64_SIZE;
    let mut owned = OwnedBinary::new(byte_len).unwrap();
    unsafe {
        std::ptr::copy_nonoverlapping(
            slice.as_ptr() as *const u8,
            owned.as_mut_slice().as_mut_ptr(),
            byte_len,
        );
    }
    owned
}

/// Safe in-place: copy binary into OwnedBinary, return (owned, num_elements).
/// The OwnedBinary is freshly allocated — mutating it is safe.
fn safe_copy(binary: &Binary) -> (OwnedBinary, usize) {
    let data = binary.as_slice();
    let num_elements = data.len() / I64_SIZE;
    let mut owned = OwnedBinary::new(data.len()).unwrap();
    owned.as_mut_slice().copy_from_slice(data);
    (owned, num_elements)
}

/// Reinterpret OwnedBinary bytes as &mut [i64].
fn owned_as_mut_slice(owned: &mut OwnedBinary, n: usize) -> &mut [i64] {
    unsafe {
        std::slice::from_raw_parts_mut(owned.as_mut_slice().as_mut_ptr() as *mut i64, n)
    }
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
fn nif_to_list(resource: ResourceArc<VecResource>) -> Vec<i64> { read_vec(&resource) }

#[rustler::nif]
fn nif_to_binary(resource: ResourceArc<VecResource>) -> OwnedBinary {
    let vec = resource.0.read().unwrap();
    slice_to_binary(&vec)
}

#[rustler::nif]
fn nif_length(resource: ResourceArc<VecResource>) -> usize {
    resource.0.read().unwrap().len()
}

#[rustler::nif]
fn nif_inspect(resource: ResourceArc<VecResource>, count: usize) -> Vec<i64> {
    let vec = resource.0.read().unwrap();
    vec.iter().take(count).copied().collect()
}

// ---------------------------------------------------------------------------
// Tier 1: Ordering — Resource (chain)
// ---------------------------------------------------------------------------

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_sort_asc(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let mut vec = read_vec(&resource);
    vec.sort_unstable();
    wrap(vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_sort_desc(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let mut vec = read_vec(&resource);
    vec.sort_unstable_by(|a, b| b.cmp(a));
    wrap(vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_reverse(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let mut vec = read_vec(&resource);
    vec.reverse();
    wrap(vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_dedup(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let mut vec = read_vec(&resource);
    vec.dedup();
    wrap(vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_uniq(resource: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let vec = read_vec(&resource);
    let mut seen = std::collections::HashSet::new();
    let result: Vec<i64> = vec.into_iter().filter(|x| seen.insert(*x)).collect();
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

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_reverse_binary(binary: Binary) -> OwnedBinary {
    let (mut owned, n) = safe_copy(&binary);
    owned_as_mut_slice(&mut owned, n).reverse();
    owned
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_dedup_binary(binary: Binary) -> OwnedBinary {
    let mut vec = binary_to_vec(&binary);
    vec.dedup();
    slice_to_binary(&vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_uniq_binary(binary: Binary) -> OwnedBinary {
    let vec = binary_to_vec(&binary);
    let mut seen = std::collections::HashSet::new();
    let result: Vec<i64> = vec.into_iter().filter(|x| seen.insert(*x)).collect();
    slice_to_binary(&result)
}

// ---------------------------------------------------------------------------
// Tier 1: Aggregation — Resource (chain)
// ---------------------------------------------------------------------------

#[rustler::nif]
fn nif_sum(resource: ResourceArc<VecResource>) -> i64 { resource.0.read().unwrap().iter().sum() }
#[rustler::nif]
fn nif_product(resource: ResourceArc<VecResource>) -> i64 { resource.0.read().unwrap().iter().product() }
#[rustler::nif]
fn nif_min(resource: ResourceArc<VecResource>) -> Option<i64> { resource.0.read().unwrap().iter().copied().min() }
#[rustler::nif]
fn nif_max(resource: ResourceArc<VecResource>) -> Option<i64> { resource.0.read().unwrap().iter().copied().max() }
#[rustler::nif]
fn nif_min_max(resource: ResourceArc<VecResource>) -> Option<(i64, i64)> {
    let vec = resource.0.read().unwrap();
    if vec.is_empty() { return None; }
    Some((*vec.iter().min().unwrap(), *vec.iter().max().unwrap()))
}
#[rustler::nif]
fn nif_count(resource: ResourceArc<VecResource>) -> usize { resource.0.read().unwrap().len() }

// ---------------------------------------------------------------------------
// Tier 1: Aggregation — Binary (one-shot)
// ---------------------------------------------------------------------------

#[rustler::nif]
fn nif_sum_binary(binary: Binary) -> i64 { binary_to_vec(&binary).iter().sum() }
#[rustler::nif]
fn nif_product_binary(binary: Binary) -> i64 { binary_to_vec(&binary).iter().product() }
#[rustler::nif]
fn nif_min_binary(binary: Binary) -> Option<i64> { binary_to_vec(&binary).iter().copied().min() }
#[rustler::nif]
fn nif_max_binary(binary: Binary) -> Option<i64> { binary_to_vec(&binary).iter().copied().max() }
#[rustler::nif]
fn nif_min_max_binary(binary: Binary) -> Option<(i64, i64)> {
    let vec = binary_to_vec(&binary);
    if vec.is_empty() { return None; }
    Some((*vec.iter().min().unwrap(), *vec.iter().max().unwrap()))
}
#[rustler::nif]
fn nif_count_binary(binary: Binary) -> usize { binary.as_slice().len() / I64_SIZE }

// ---------------------------------------------------------------------------
// Tier 1: Access — Resource (chain)
// ---------------------------------------------------------------------------

#[rustler::nif]
fn nif_at(resource: ResourceArc<VecResource>, index: i64) -> Option<i64> {
    let vec = resource.0.read().unwrap();
    let len = vec.len() as i64;
    let actual = if index < 0 { len + index } else { index };
    if actual < 0 || actual >= len { None } else { Some(vec[actual as usize]) }
}

#[rustler::nif]
fn nif_slice(resource: ResourceArc<VecResource>, start: usize, len: usize) -> ResourceArc<VecResource> {
    let vec = resource.0.read().unwrap();
    let end = std::cmp::min(start + len, vec.len());
    let start = std::cmp::min(start, vec.len());
    wrap(vec[start..end].to_vec())
}

#[rustler::nif]
fn nif_take(resource: ResourceArc<VecResource>, count: i64) -> ResourceArc<VecResource> {
    let vec = read_vec(&resource);
    let result = if count >= 0 {
        let n = std::cmp::min(count as usize, vec.len());
        vec[..n].to_vec()
    } else {
        let n = std::cmp::min((-count) as usize, vec.len());
        vec[vec.len() - n..].to_vec()
    };
    wrap(result)
}

#[rustler::nif]
fn nif_drop(resource: ResourceArc<VecResource>, count: i64) -> ResourceArc<VecResource> {
    let vec = read_vec(&resource);
    let result = if count >= 0 {
        let n = std::cmp::min(count as usize, vec.len());
        vec[n..].to_vec()
    } else {
        let n = std::cmp::min((-count) as usize, vec.len());
        vec[..vec.len() - n].to_vec()
    };
    wrap(result)
}

#[rustler::nif]
fn nif_member(resource: ResourceArc<VecResource>, value: i64) -> bool {
    resource.0.read().unwrap().contains(&value)
}

// ---------------------------------------------------------------------------
// Tier 1: Access — Binary (one-shot)
// ---------------------------------------------------------------------------

#[rustler::nif]
fn nif_at_binary(binary: Binary, index: i64) -> Option<i64> {
    let vec = binary_to_vec(&binary);
    let len = vec.len() as i64;
    let actual = if index < 0 { len + index } else { index };
    if actual < 0 || actual >= len { None } else { Some(vec[actual as usize]) }
}

#[rustler::nif]
fn nif_slice_binary(binary: Binary, start: usize, len: usize) -> OwnedBinary {
    let vec = binary_to_vec(&binary);
    let end = std::cmp::min(start + len, vec.len());
    let start = std::cmp::min(start, vec.len());
    slice_to_binary(&vec[start..end])
}

#[rustler::nif]
fn nif_take_binary(binary: Binary, count: i64) -> OwnedBinary {
    let vec = binary_to_vec(&binary);
    let result = if count >= 0 {
        let n = std::cmp::min(count as usize, vec.len());
        &vec[..n]
    } else {
        let n = std::cmp::min((-count) as usize, vec.len());
        &vec[vec.len() - n..]
    };
    slice_to_binary(result)
}

#[rustler::nif]
fn nif_drop_binary(binary: Binary, count: i64) -> OwnedBinary {
    let vec = binary_to_vec(&binary);
    let result = if count >= 0 {
        let n = std::cmp::min(count as usize, vec.len());
        &vec[n..]
    } else {
        let n = std::cmp::min((-count) as usize, vec.len());
        &vec[..vec.len() - n]
    };
    slice_to_binary(result)
}

#[rustler::nif]
fn nif_member_binary(binary: Binary, value: i64) -> bool {
    binary_to_vec(&binary).contains(&value)
}

// ---------------------------------------------------------------------------
// Tier 1: Combination — Resource (chain)
// ---------------------------------------------------------------------------

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_concat(resource: ResourceArc<VecResource>, other: ResourceArc<VecResource>) -> ResourceArc<VecResource> {
    let mut vec = read_vec(&resource);
    vec.extend_from_slice(&read_vec(&other));
    wrap(vec)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_frequencies(resource: ResourceArc<VecResource>) -> HashMap<i64, usize> {
    let vec = resource.0.read().unwrap();
    let mut map = HashMap::new();
    for &v in vec.iter() { *map.entry(v).or_insert(0) += 1; }
    map
}

#[rustler::nif]
fn nif_empty(resource: ResourceArc<VecResource>) -> bool { resource.0.read().unwrap().is_empty() }

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_join(resource: ResourceArc<VecResource>, separator: String) -> String {
    let vec = resource.0.read().unwrap();
    vec.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(&separator)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_with_index(resource: ResourceArc<VecResource>, offset: i64) -> Vec<(i64, i64)> {
    let vec = resource.0.read().unwrap();
    vec.iter().enumerate().map(|(i, &v)| (v, i as i64 + offset)).collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_zip(res1: ResourceArc<VecResource>, res2: ResourceArc<VecResource>) -> Vec<(i64, i64)> {
    let v1 = res1.0.read().unwrap();
    let v2 = res2.0.read().unwrap();
    v1.iter().zip(v2.iter()).map(|(&a, &b)| (a, b)).collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_chunk_every(resource: ResourceArc<VecResource>, count: usize) -> Vec<Vec<i64>> {
    let vec = resource.0.read().unwrap();
    vec.chunks(count).map(|c| c.to_vec()).collect()
}

// ---------------------------------------------------------------------------
// Tier 1: Combination — Binary (one-shot)
// ---------------------------------------------------------------------------

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_concat_binary(binary1: Binary, binary2: Binary) -> OwnedBinary {
    let s1 = binary1.as_slice();
    let s2 = binary2.as_slice();
    let mut owned = OwnedBinary::new(s1.len() + s2.len()).unwrap();
    owned.as_mut_slice()[..s1.len()].copy_from_slice(s1);
    owned.as_mut_slice()[s1.len()..].copy_from_slice(s2);
    owned
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_frequencies_binary(binary: Binary) -> HashMap<i64, usize> {
    let vec = binary_to_vec(&binary);
    let mut map = HashMap::new();
    for v in vec { *map.entry(v).or_insert(0) += 1; }
    map
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_join_binary(binary: Binary, separator: String) -> String {
    let vec = binary_to_vec(&binary);
    vec.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(&separator)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_with_index_binary(binary: Binary, offset: i64) -> Vec<(i64, i64)> {
    let vec = binary_to_vec(&binary);
    vec.iter().enumerate().map(|(i, &v)| (v, i as i64 + offset)).collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_zip_binary(binary1: Binary, binary2: Binary) -> Vec<(i64, i64)> {
    let v1 = binary_to_vec(&binary1);
    let v2 = binary_to_vec(&binary2);
    v1.iter().zip(v2.iter()).map(|(&a, &b)| (a, b)).collect()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn nif_chunk_every_binary(binary: Binary, count: usize) -> Vec<Vec<i64>> {
    let vec = binary_to_vec(&binary);
    vec.chunks(count).map(|c| c.to_vec()).collect()
}

// ---------------------------------------------------------------------------
// Legacy list-protocol NIFs (kept for compatibility)
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
    let mut seen = std::collections::HashSet::new();
    list.into_iter().filter(|x| seen.insert(*x)).collect()
}
#[rustler::nif]
fn nif_sum_list(list: Vec<i64>) -> i64 { list.iter().sum() }
#[rustler::nif]
fn nif_product_list(list: Vec<i64>) -> i64 { list.iter().product() }
#[rustler::nif]
fn nif_min_list(list: Vec<i64>) -> Option<i64> { list.iter().copied().min() }
#[rustler::nif]
fn nif_max_list(list: Vec<i64>) -> Option<i64> { list.iter().copied().max() }
#[rustler::nif]
fn nif_min_max_list(list: Vec<i64>) -> Option<(i64, i64)> {
    if list.is_empty() { return None; }
    Some((*list.iter().min().unwrap(), *list.iter().max().unwrap()))
}
#[rustler::nif]
fn nif_count_list(list: Vec<i64>) -> usize { list.len() }
#[rustler::nif]
fn nif_at_list(list: Vec<i64>, index: i64) -> Option<i64> {
    let len = list.len() as i64;
    let actual = if index < 0 { len + index } else { index };
    if actual < 0 || actual >= len { None } else { Some(list[actual as usize]) }
}
#[rustler::nif]
fn nif_slice_list(list: Vec<i64>, start: usize, len: usize) -> Vec<i64> {
    let end = std::cmp::min(start + len, list.len());
    let start = std::cmp::min(start, list.len());
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
fn nif_concat_list(list1: Vec<i64>, list2: Vec<i64>) -> Vec<i64> { let mut r = list1; r.extend_from_slice(&list2); r }
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_frequencies_list(list: Vec<i64>) -> HashMap<i64, usize> {
    let mut map = HashMap::new(); for v in list { *map.entry(v).or_insert(0) += 1; } map
}
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_join_list(list: Vec<i64>, separator: String) -> String {
    list.iter().map(|x| x.to_string()).collect::<Vec<_>>().join(&separator)
}
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_with_index_list(list: Vec<i64>, offset: i64) -> Vec<(i64, i64)> {
    list.iter().enumerate().map(|(i, &v)| (v, i as i64 + offset)).collect()
}
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_zip_list(list1: Vec<i64>, list2: Vec<i64>) -> Vec<(i64, i64)> {
    list1.iter().zip(list2.iter()).map(|(&a, &b)| (a, b)).collect()
}
#[rustler::nif(schedule = "DirtyCpu")]
fn nif_chunk_every_list(list: Vec<i64>, count: usize) -> Vec<Vec<i64>> {
    list.chunks(count).map(|c| c.to_vec()).collect()
}

rustler::init!("Elixir.FEnum.Native");
