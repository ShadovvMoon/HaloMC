extern crate tritium;
use tritium::map::Map;

#[no_mangle]
pub unsafe extern fn map_from_pointer(ptr : *const u8, length : usize) -> *mut Map {
    Box::into_raw(Box::new(Map::from_cache_file(std::slice::from_raw_parts(ptr,length)).unwrap()))
}

#[no_mangle]
pub unsafe extern fn get_tag(map : *mut Map, tag_path : *const i8, tag_class : u32, new_tag_id : usize) -> *const u8 {
    let tag_path_utf8 = std::ffi::CStr::from_ptr(tag_path).to_str().unwrap().to_owned();
    let tag_id = (*map).tag_array.find_tag(&tag_path_utf8,tag_class).unwrap();
    let tag = &mut (*map).tag_array.tags_mut()[tag_id];
    let tag_pointer = tag.data.as_ref().unwrap().as_ptr() as u32;
    if !tag.implicit {
        tag.set_memory_address(tag_pointer);
        let references = tag.references(&(*map).tag_array);
        for mut i in references {
            i.tag_index = new_tag_id & 0xFFFF;
            tag.set_reference(&i);
        }
        tag.implicit = true;
    }
    tag_pointer as *const _
}

#[no_mangle]
pub unsafe extern fn free_map(map : *mut Map) {
    if map != 0 as *mut _ {
        Box::from_raw(map);
    }
}
