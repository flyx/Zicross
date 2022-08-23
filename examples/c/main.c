#include<stdbool.h>
#include<stdlib.h>
#include<stdio.h>

#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>

#include "resources.h"

#define try(func, ...) {\
  int ret = func(__VA_ARGS__);\
  if (ret != 0) {\
    puts("call failed: " #func "(" #__VA_ARGS__ ")");\
    exit(1);\
  }\
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

int main() {
  loadData();
  
  try(SDL_Init, SDL_INIT_VIDEO|SDL_INIT_EVENTS|SDL_INIT_AUDIO);
  SDL_Window *window = SDL_CreateWindow(
    "Zicross demo", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 640, 480,
    SDL_WINDOW_SHOWN);
  
  SDL_Renderer *renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
  
  while (true) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) if (event.type == SDL_QUIT) {
      // velociraptors
      goto after_main_loop;
    }
    
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    SDL_RenderClear(renderer);
    
    int w, h;
    SDL_GetRendererOutputSize(renderer, &w, &h);
    SDL_Rect rect = {
      .x = (w - 401) / 2,
      .y = (h - 201) / 2,
      .w = 401,
      .h = 201
    };
    SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255);
    SDL_RenderFillRect(renderer, &rect);
    
    SDL_SetRenderDrawColor(renderer, 128, 128, 128, 255);
    SDL_RenderSetScale(renderer, 1.0, 1.0);
    for (int i = 0; i < 20; ++i) {
      SDL_RenderDrawLine(
        renderer, rect.x, rect.y + i * 10,
        rect.x + rect.w, rect.y + i * 10);
    }
    for (int i = 0; i < 40; ++i) {
      SDL_RenderDrawLine(
        renderer, rect.x + i * 10, rect.y,
        rect.x + i * 10, rect.y + rect.h);
    }
    
    SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
    for (size_t y = 0; y < 20; ++y) {
      for (size_t x = 0; x < 40; ++x) {
        if (data[y][x]) {
          SDL_RenderFillRect(renderer, &(SDL_Rect) {
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
}