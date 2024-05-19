__includes ["create_patches.nls"]

turtles-own [speed]

to setup
  clear-all

  create-light-green-patches
  create-dark-green-clusters 5
  setup-lines 20
  create-rectangle

  setup-turtles

  reset-ticks
end

to setup-turtles
  let available-patches patches with [pcolor != blue] ;; Wybieramy dostępne patche, których kolor nie jest niebieski
  create-turtles 3 [
    move-to one-of available-patches ;; Umieszczamy żółwie na losowym z tych patchy
    set color brown - 2
    set size 2
    set speed 1
  ]
end

;;;;;;;;;;;;;;;;;;;;;
;;; Go procedures ;;;
;;;;;;;;;;;;;;;;;;;;;

to go
  ask turtles [
    while [not can-move? 1] [
      random-turn-turtle ;; Jeśli dojdzie do krawędzi świata obraca się o 45 stopni
    ]

    let direction decide-direction
    while [direction = 2] [
      random-turn-turtle
      set direction decide-direction
    ]
    move-in-direction direction

  ]
  tick
end

to move-in-direction [direction]
  if direction = 0 [
    fd speed
  ]
  if direction = 1 [
    rt 90
    set direction decide-direction
    move-in-direction direction
  ]
  if direction = -1 [
    rt -90
    set direction decide-direction
    move-in-direction direction
  ]
end

to-report decide-direction
  let ahead-patch patch-ahead 1
  ifelse ahead-patch != nobody and [pcolor] of ahead-patch = blue [
    let right-diagonal-patch patch-right-and-ahead 1 45
    ifelse right-diagonal-patch != nobody and [pcolor] of right-diagonal-patch = blue  [
      set color yellow
      report 1 ;; Patche niebieskie są po prawej stronie
    ] [
      let left-diagonal-patch patch-right-and-ahead 1 -45
      ifelse left-diagonal-patch != nobody and [pcolor] of left-diagonal-patch = blue  [
        set color red
        report -1 ;; Patche niebieskie są po lewej stronie
      ] [
        set color orange
        report 2 ;; Patche niebieskie są tylko na prostej drodze, żółw musi się obrócić
      ]
    ]
  ] [
    set color brown - 2
    report 0 ;; Brak patchy niebieskich na drodze
  ]
end

to random-turn-turtle
  ifelse random-float 1 < 0.5 [
    rt 45
  ] [
    rt -45
  ]
end