#pragma once

// CSkia.h — Subset da API C pública do Skia (sk_*) que usaremos.
// Quando integrar o Skia real, substitua pelo header oficial em:
//   skia/include/c/sk_canvas.h  (e adjacentes)
// Binários pré-compilados: https://github.com/nicklockwood/SwiftSkia (fork)

#include <stdint.h>
#include <stdbool.h>

typedef void* sk_surface_t;
typedef void* sk_canvas_t;
typedef void* sk_paint_t;
typedef void* sk_font_t;
typedef void* sk_typeface_t;
typedef void* sk_rrect_t;

typedef struct {
    float left, top, right, bottom;
} sk_rect_t;

typedef uint32_t sk_color_t;  // 0xAARRGGBB

// Surface
sk_surface_t* sk_surface_new_raster_n32_premul(int width, int height);
void          sk_surface_unref(sk_surface_t* surface);
sk_canvas_t*  sk_surface_get_canvas(sk_surface_t* surface);

// Canvas
void sk_canvas_clear(sk_canvas_t* canvas, sk_color_t color);
void sk_canvas_flush(sk_canvas_t* canvas);
void sk_canvas_save(sk_canvas_t* canvas);
void sk_canvas_restore(sk_canvas_t* canvas);
void sk_canvas_clip_rect(sk_canvas_t* canvas, const sk_rect_t* rect);

// Desenho
void sk_canvas_draw_rect(sk_canvas_t* canvas, const sk_rect_t* rect, sk_paint_t* paint);
void sk_canvas_draw_rrect(sk_canvas_t* canvas, sk_rrect_t* rrect, sk_paint_t* paint);
void sk_canvas_draw_string(
    sk_canvas_t* canvas,
    const char* str,
    float x, float y,
    sk_font_t* font,
    sk_paint_t* paint
);

// Paint
sk_paint_t* sk_paint_new(void);
void        sk_paint_delete(sk_paint_t* paint);
void        sk_paint_set_color(sk_paint_t* paint, sk_color_t color);
void        sk_paint_set_antialias(sk_paint_t* paint, bool antialias);

// RRect (retângulo com cantos arredondados)
sk_rrect_t* sk_rrect_new(void);
void        sk_rrect_delete(sk_rrect_t* rrect);
void        sk_rrect_set_rect_radii(sk_rrect_t* rrect, const sk_rect_t* rect, float radius);

// Font / Typeface
sk_typeface_t* sk_typeface_make_from_name(const char* familyName, int style);
sk_font_t*     sk_font_new(sk_typeface_t* typeface, float size);
void           sk_font_delete(sk_font_t* font);
