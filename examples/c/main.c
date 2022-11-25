#include<stdbool.h>
#include<stdlib.h>
#include<stdio.h>

#ifdef __APPLE__
#include <SDL.h>
#else
#include <SDL2/SDL.h>
#endif

#include "resources.h"

#define callAndCheck(var, check, func, ...)\
  var = func(__VA_ARGS__);\
  if (check) {\
    puts("call failed: " #func "(" #__VA_ARGS__ ")");\
    printf("  error: %s\n", SDL_GetError());\
    exit(1);\
  }

#define trySet(var, func, ...)\
  callAndCheck(var, var == NULL, func, __VA_ARGS__)

#define try(func, ...) {\
  int ret;\
  callAndCheck(ret, ret != 0, func, __VA_ARGS__);\
}

bool data[20][40];

void loadData() {
  FILE *file = fopen(resources_data, "r");
  if (file == NULL) {
    printf("unable to open file: %s\n", resources_data);
    exit(1);
  }
  for (size_t i = 0; i < 20; ++i) {
    char buffer[42];
    fgets(buffer, 42, file);
    bool line_end = false;
    for (size_t j = 0; j < 40; ++j) {
      if (!line_end) {
        if (buffer[j] == '\n') {
          line_end = true;
        } else {
          data[i][j] = buffer[j] == 'x';
          continue;
        }
      }
      data[i][j] = false;
    }
  }
  fclose(file);
}

int main(int argc, char *argv[]) {
  loadData();
  
  try(SDL_Init, SDL_INIT_VIDEO|SDL_INIT_EVENTS|SDL_INIT_AUDIO);
  SDL_Window *window;
  trySet(window, SDL_CreateWindow,
    "Zicross demo", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 640, 480,
    SDL_WINDOW_SHOWN);
  
  SDL_Renderer *renderer;
  trySet(renderer, SDL_CreateRenderer, window, -1, SDL_RENDERER_ACCELERATED);
  
  while (true) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) if (event.type == SDL_QUIT) {
      goto after_main_loop; // velociraptors
    }
    
    try(SDL_SetRenderDrawColor, renderer, 0, 0, 0, 255);
    try(SDL_RenderClear, renderer);
    
    int w, h;
    try(SDL_GetRendererOutputSize, renderer, &w, &h);
    SDL_Rect rect = {
      .x = (w - 401) / 2,
      .y = (h - 201) / 2,
      .w = 401,
      .h = 201
    };
    try(SDL_SetRenderDrawColor, renderer, 255, 255, 255, 255);
    try(SDL_RenderFillRect, renderer, &rect);
    
    try(SDL_SetRenderDrawColor, renderer, 128, 128, 128, 255);
    try(SDL_RenderSetScale, renderer, 1.0, 1.0);
    for (int i = 0; i < 20; ++i) {
      try(SDL_RenderDrawLine,
        renderer, rect.x, rect.y + i * 10,
        rect.x + rect.w, rect.y + i * 10);
    }
    for (int i = 0; i < 40; ++i) {
      try(SDL_RenderDrawLine,
        renderer, rect.x + i * 10, rect.y,
        rect.x + i * 10, rect.y + rect.h);
    }
    
    try(SDL_SetRenderDrawColor, renderer, 0, 0, 0, 255);
    for (size_t y = 0; y < 20; ++y) {
      for (size_t x = 0; x < 40; ++x) {
        if (data[y][x]) {
          try(SDL_RenderFillRect, renderer, &(SDL_Rect) {
            .x = rect.x + x * 10,
            .y = rect.y + y * 10,
            .w = 10,
            .h = 10
          });
        }
      }
    }
    
    SDL_RenderPresent(renderer);
  }
  after_main_loop:
  
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit();
  return 0;
}