-- Base ESTÁTICA da entrada (frame_00 = câmara ritual PixelLab 256×192).
-- v3 (Jul/2026): o loop de 11 frames "piscava" (shimmer do PixelLab v3), então
-- ficou UM frame estável (usado só como FALLBACK do shader boot_splash.glsl).
-- fps só existiria caso se volte a um loop de frames.
return { fps = 9, frames = 1 }
