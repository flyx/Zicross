package main

import (
  "bufio"
  "os"
  
  "github.com/veandco/go-sdl2/sdl"
)

var data [20][40]bool

func init() {
  file, err := os.Open(LogoPath)
  if err != nil { panic(err) }
  scanner := bufio.NewScanner(file)
  y := 0
  for scanner.Scan() {
    line := scanner.Text()
    for x := 0; x < len(line); x++ {
      data[y][x] = line[x] == 'x'
    }
    y++
  }
}

func main() {
  if err := sdl.Init(sdl.INIT_VIDEO | sdl.INIT_EVENTS | sdl.INIT_AUDIO); err != nil {
    panic(err)
  }
  defer sdl.Quit()
  
  window, err := sdl.CreateWindow("Zicross Demo",
    sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED,
    640, 480, sdl.WINDOW_SHOWN)
  if err != nil { panic(err) }
  defer window.Destroy()
  
  renderer, err := sdl.CreateRenderer(window, -1, sdl.RENDERER_ACCELERATED)
  if err != nil { panic(err) }
  
  for running := true; running; {
    for event := sdl.PollEvent(); event != nil; event = sdl.PollEvent() {
      switch event.(type) {
      case *sdl.QuitEvent:
        running = false
        break
      }
    }
    renderer.SetDrawColor(0, 0, 0, 255)
    renderer.Clear()
    
    w, h, err := renderer.GetOutputSize()
    if err != nil { panic(err) }
    rect := &sdl.Rect{
      X: (w - 401) / 2,
      Y: (h - 201) / 2,
      W: 401,
      H: 201,
    }
    renderer.SetDrawColor(255, 255, 255, 255)
    renderer.FillRect(rect)
    
    renderer.SetDrawColor(128, 128, 128, 255)
    for i := int32(0); int(i) < len(data); i++ {
      renderer.SetScale(1.0, 1.0)
      renderer.DrawLine(rect.X, rect.Y + i * 10, rect.X + rect.W, rect.Y + i * 10)
    }
    for i := int32(0); int(i) < len(data[0]); i++ {
      renderer.SetScale(1.0, 1.0)
      renderer.DrawLine(rect.X + i * 10, rect.Y, rect.X + i * 10, rect.Y + rect.H)
    }
    
    renderer.SetDrawColor(0, 0, 0, 255)
    for y, row := range data {
      for x, cell := range row {
        if cell {
          renderer.FillRect(&sdl.Rect{
            X: rect.X + int32(x) * 10,
            Y: rect.Y + int32(y) * 10,
            W: 10,
            H: 10,
          })
        }
      }
    }
    
    renderer.Present()
  }
  
}