// SDL3 / SDL3_ttf 的 C 绑定。只在一处 @cImport，其余模块都从这里取符号。
pub const c = @cImport({
    @cDefine("SDL_MAIN_HANDLED", "1");
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
