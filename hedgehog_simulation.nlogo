__includes ["create_patches.nls"]

turtles-own [speed]

to setup
  clear-all

  create-light-green-patches
  create-dark-green-clusters 5
  setup-lines 10
  create-rectangle

  setup-turtles

  reset-ticks
end

to setup-turtles
  let available-patches patches with [pcolor != blue] ;; Wybieramy dostępne patche, których kolor nie jest niebieski
  create-turtles 3 [
    move-to one-of available-patches
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
;    if random-float 1 < 0.02 [ ;;2% szans że jednak zboczy z prostej drogi
;      ifelse random 2 = 0 [rt random 46 + 45] [lt random 46 + 45]
;    ]

    while [not can-move? 1] [
      random-turn-turtle ;; Jeśli dojdzie do krawędzi świata obraca się o 45 stopni
    ]

    let direction decide-direction
    move-in-direction direction

  ]
  tick
end

to move-in-direction [direction]
  if direction = 0 [
    fd speed
  ]
  if direction = 1 or direction = 2 [
    rt 45
    set direction decide-direction
    move-in-direction direction
  ]
  if direction = -1 [
    lt 45
    set direction decide-direction
    move-in-direction direction
  ]
end

to-report decide-direction
  let ahead-patch patch-ahead 1
  ifelse ahead-patch != nobody and [pcolor] of ahead-patch = blue [
    let right-diagonal-patch patch-right-and-ahead 1 45
    ifelse right-diagonal-patch != nobody and [pcolor] of right-diagonal-patch = blue  [
      let left-diagonal-patch patch-right-and-ahead 1 -45
      ifelse left-diagonal-patch != nobody and [pcolor] of left-diagonal-patch = blue  [
        report 2 ;; Jest otoczony ogrodzeniem
      ] [
        report -1 ;; Po lewo nie ma ogrodzenia
      ]
    ] [
      report 1 ;; Po prawo nie ma ogrodzenia
    ]
  ] [
    report 0 ;; Brak ogrodzenia na przeciwko
  ]
end

to random-turn-turtle
  ifelse random-float 1 < 0.5 [
    rt 45
  ] [
    lt 45
  ]
end

