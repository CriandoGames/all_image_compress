use std::slice;
use std::io::Cursor;
use image::{ColorType, ImageEncoder};
use image::imageops::FilterType;

extern crate oxipng;
extern crate webp;
// Definição dos formatos aceitos vindos do Dart
#[repr(i32)]
#[derive(Debug, Clone, Copy)]
pub enum CompressFormat {
    Jpeg = 0,
    Png = 1,
    Webp = 2,
    Gif = 3,
    Bmp = 4,
    Tiff = 5,
}

impl CompressFormat {
    fn from_i32(value: i32) -> Self {
        match value {
            0 => CompressFormat::Jpeg,
            1 => CompressFormat::Png,
            2 => CompressFormat::Webp,
            3 => CompressFormat::Gif,
            4 => CompressFormat::Bmp,
            5 => CompressFormat::Tiff,
            _ => CompressFormat::Jpeg,
        }
    }
}

// Struct de retorno compatível com o FFI do Dart
#[repr(C)]
pub struct NativeCompressResult {
    pub bytes_ptr: *mut u8,
    pub bytes_len: usize,
    pub width: u32,
    pub height: u32,
}

#[no_mangle]
pub unsafe extern "C" fn rust_compress(
    input_ptr: *const u8,
    input_len: usize,
    quality: u8,
    max_width: i32,
    max_height: i32,
    format_type: i32,
) -> NativeCompressResult {
    let input_bytes = slice::from_raw_parts(input_ptr, input_len);
    let format = CompressFormat::from_i32(format_type);

    let img = match image::load_from_memory(input_bytes) {
        Ok(decoded) => decoded,
        Err(_) => return failure_result(),
    };

    let (orig_w, orig_h) = (img.width(), img.height());
    let (target_w, target_h) = calculate_dimensions(orig_w, orig_h, max_width, max_height);

    let resized_img = if target_w != orig_w || target_h != orig_h {
        img.resize(target_w, target_h, FilterType::Triangle)
    } else {
        img
    };

    let width = resized_img.width();
    let height = resized_img.height();
    let mut compressed_bytes = Vec::new();

    let encode_success = match format {
        CompressFormat::Jpeg => {
            let  encoder = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut compressed_bytes, quality);
            encoder.write_image(resized_img.as_bytes(), width, height, resized_img.color().into()).is_ok()
        }
        
        CompressFormat::Png => {
            use image::codecs::png::{PngEncoder, CompressionType, FilterType as PngFilter};
            
            let temp_buffer;
            let raw_pixels = match resized_img.as_rgba8() {
                Some(buf) => buf.as_raw(),
                None => {
                    temp_buffer = resized_img.to_rgba8();
                    temp_buffer.as_raw()
                }
            };
            
            let mut raw_png_bytes = Vec::new();
            let encoder = PngEncoder::new_with_quality(&mut raw_png_bytes, CompressionType::Fast, PngFilter::NoFilter);
            
            if encoder.write_image(raw_pixels, width, height, ColorType::Rgba8.into()).is_err() {
                false
            } else {
                let mut options = oxipng::Options::from_preset(2); 
                options.interlace = None; 
                options.strip = oxipng::StripChunks::All; 

                match oxipng::optimize_from_memory(&raw_png_bytes, &options) {
                    Ok(optimized_bytes) => {
                        compressed_bytes = optimized_bytes;
                        true
                    }
                    Err(_) => {
                        compressed_bytes = raw_png_bytes;
                        true
                    }
                }
            }
        }

        CompressFormat::Webp => {
            match webp::Encoder::from_image(&resized_img) {
                Ok(encoder) => {
                    compressed_bytes = encoder.encode(quality as f32).to_vec();
                    true
                }
                Err(_) => false,
            }
        }

        CompressFormat::Gif => {
            use image::codecs::gif::GifEncoder;
            let rgba_data = resized_img.to_rgba8();
            let mut encoder = GifEncoder::new(&mut compressed_bytes);
            encoder.encode(rgba_data.as_raw(), width, height, ColorType::Rgba8.into()).is_ok()
        }

        CompressFormat::Bmp => {
            use image::codecs::bmp::BmpEncoder;
            let rgba_data = resized_img.to_rgba8();
            let mut encoder = BmpEncoder::new(&mut compressed_bytes);
            encoder.encode(rgba_data.as_raw(), width, height, ColorType::Rgba8.into()).is_ok()
        }

        CompressFormat::Tiff => {
            use image::codecs::tiff::TiffEncoder;
            let rgba_data = resized_img.to_rgba8();
            let mut cursor = Cursor::new(&mut compressed_bytes);
            let encoder = TiffEncoder::new(&mut cursor);
            encoder.write_image(rgba_data.as_raw(), width, height, ColorType::Rgba8.into()).is_ok()
        }
    };

    if !encode_success || compressed_bytes.is_empty() {
        return failure_result();
    }

    let mut boxed_slice = compressed_bytes.into_boxed_slice();
    let bytes_ptr = boxed_slice.as_mut_ptr();
    let bytes_len = boxed_slice.len();
    std::mem::forget(boxed_slice);

    NativeCompressResult { bytes_ptr, bytes_len, width, height }
}

#[no_mangle]
pub unsafe extern "C" fn rust_free_bytes(ptr: *mut u8, len: usize) {
    if !ptr.is_null() {
        let _ = Box::from_raw(slice::from_raw_parts_mut(ptr, len));
    }
}

fn failure_result() -> NativeCompressResult {
    NativeCompressResult {
        bytes_ptr: std::ptr::null_mut(),
        bytes_len: 0,
        width: 0,
        height: 0,
    }
}

fn calculate_dimensions(width: u32, height: u32, max_width: i32, max_height: i32) -> (u32, u32) {
    if max_width <= 0 && max_height <= 0 {
        return (width, height);
    }

    let mut target_w = width as f64;
    let mut target_h = height as f64;
    let aspect_ratio = target_w / target_h;

    if max_width > 0 && target_w > max_width as f64 {
        target_w = max_width as f64;
        target_h = target_w / aspect_ratio;
    }

    if max_height > 0 && target_h > max_height as f64 {
        target_h = max_height as f64;
        target_w = target_h * aspect_ratio;
    }

    (target_w.round() as u32, target_h.round() as u32)
}