__includes ["setup_world//setup_world.nls" "go_procedures//go_procedure.nls"]

extensions[qlearningextension array]

breed [hedgehogs hedgehog]

globals [
  possible-actions possible-angles
  night-duration current-time episode-counter
  return-probability max-distance
  avg-mass std-dev low-mass-threshold high-mass-threshold
  hedgehog-memory hedgehog-data
  fence street urban ;o to też można później uprościć
  environment-types
  avoided-patches available-patches
]

hedgehogs-own [
  sex
  mass
  speed distance-traveled
  visited-patches last-heading
  nest
  flags
  terrain-color food-here fence-ahead distance-to-nest stay-in-nest
]

patches-own [
  environment-type
  food
  visit-count
  og-color
  ;isNest
]

to setup
  clear-all
  reset-ticks

  print "Loading image"
  setup-world-from-image "D:/GitHub/Hedgehog_ABM/setup_world/maps/map_2.png" 285 151 ;190 100 ;571 302 ;857 453
  print "Image loaded"

  print "Setting up world"
  setup-world
  print "World setup completed" ;; <-- to się liczy najdłużej

  setup-variables
  print "Variables setup completed"



  setup-hedgehogs
  print "Hedgehogs setup completed"


  if file-exists? "results//hedgehog-data.csv" [ file-delete "results//hedgehog-data.csv" ]
  set hedgehog-data array:from-list n-values 6 [0]
  collect-hedgehog-data

  print "Setup completed."
end

to setup-variables
  set night-duration 60 ;; 60 ticków na godzinę
  set current-time 0
  set episode-counter 0
  set return-probability 0.05
  set max-distance 20
  set possible-angles [0 45 90 135 180 225 270 315]
  set hedgehog-memory 10
  set avg-mass 846 ;;na razie dla samców
  set std-dev 119  ;;na razie dla samców
  set low-mass-threshold avg-mass * 0.6
  set high-mass-threshold avg-mass * 1.5

  set fence red
  set street black
  set urban yellow

  set environment-types ["ogrod-tylny-domu-blizniaczego" "ogrod-frontowy-domu-blizniaczego" "ogrod-tylny-domu-wolnostojacego" "ogrod-frontowy-domu-wolnostojacego"]
  set avoided-patches (list fence street urban)
  show avoided-patches
  set available-patches patches with [
    not member? pcolor avoided-patches
    and not any? neighbors4 with [member? pcolor avoided-patches]
  ]
  show available-patches
end

to setup-hedgehogs
  create-hedgehogs 4 [
    set sex ifelse-value (random-float 1 > 0.5) [0] [1] ;;50% szans że samica=1
    set color ifelse-value (sex = 0) [brown - 2] [brown + 1]
    set mass random-normal avg-mass std-dev
    set size 3.5
    set speed 1
    set distance-traveled 0

    move-to one-of available-patches
    ;let nearest-nest min-one-of available-patches with [is-nest?] [distance self]
    ;set nest nearest-nest
    ;set nest one-of available-patches
    ;move-to nest
    ;ask nest [ set pcolor brown ]
    ;set nest nobody
    set visited-patches (list patch-here)

    random-turn-hedgehog
    set flags []
    set last-heading heading
    set stay-in-nest false
    update-state-variables
  ]

  ask hedgehogs [
    qlearningextension:state-def ["terrain-color" "fence-ahead" "food-here" "mass" "distance-to-nest"]
    (qlearningextension:actions [forage] [eat-food] [go-to-nest])
    qlearningextension:reward [reward-func]
    qlearningextension:end-episode [isEndState] reset-episode
    qlearningextension:action-selection "e-greedy" [0.25 0.99]
    ;qlearningextension:action-selection-egreedy 0.75 "rate" 0.95
    qlearningextension:learning-rate 1
    qlearningextension:discount-factor 0.75
  ]
end

to update-state-variables
  ask hedgehogs [
    set terrain-color [pcolor] of patch-here
    set food-here [food] of patch-here
    set mass mass
    let ahead-patch patch-ahead 1
    set fence-ahead ifelse-value (ahead-patch != nobody and ( any? patches in-cone 2 90 with [pcolor = fence])) [1] [0]
    ifelse [nest] of myself != 0 [ set distance-to-nest distance [nest] of myself ] [ set distance-to-nest -1 ]
    set flags []
    ;update-visited-patches
  ]
end

to-report reward-func
  let penalty 0
  if member? "rotated-180" flags [
    set penalty -100
  ]

  let reward 0
  (ifelse
    member? "eat-food-fail" flags [
       set penalty (-1 + penalty)
    ]
    member? "eat-food-big-fail" flags [
       set penalty (-20 + penalty)
    ]
    member? "build-nest-fail" flags [
       set penalty (-5 + penalty)
    ]
    member? "go-to-nest-fail" flags [
       set penalty (-5 + penalty)
    ]
    member? "build-nest-success" flags [
       set reward (0 + penalty)
    ]
    member? "eat-food-success" flags [
       set reward (3 + penalty)
    ]
    member? "eat-food-big-success" flags [
       set reward (10 + penalty)
    ]
    member? "go-to-nest-success" flags [
       set reward (3 + penalty)
    ]
    member? "forage" flags [
       set reward (10 + penalty)
    ]
    [  set reward (0 + penalty) ]
  )
  if not member? patch-here visited-patches [
    set reward (reward + 20)
  ]
  report (reward + penalty)
end

to-report isEndState
  report current-time >= night-duration
end

to reset-episode
  collect-hedgehog-data
  export-data
  if not any? hedgehogs [
      user-message "Wszystkie jeże nie żyją. Symulacja została przerwana."
      stop
  ]
  ask hedgehogs [
    ;face-patch nest
    set mass mass - ((random-float 5 + 5) + (floor (distance-traveled / 500) * 5)) ;;tracą 5-10g dziennie i 5g za każde przebyte 500m
    set stay-in-nest false
    set distance-traveled 0
  ]
  set current-time 0
  set return-probability 0
  set episode-counter episode-counter + 1
  if episode-counter mod 7 = 0 [
    renew-resources
  ]
  reset-ticks
  ;;reset rewards?
end

to renew-resources
  ask patches [
    if member? self environment-types [
      set food food + random 5 + 3 ;;różne środowiska może z inną prędkością powinny?
    ]
  ]
end

to-report time-percent-in-env [env-type]
  let total-visits sum [visit-count] of patches
  let visits-in-env sum [visit-count] of patches with [environment-type = env-type]
  report (visits-in-env / total-visits) * 100
end

to collect-hedgehog-data
  array:set hedgehog-data 0 ticks
  ifelse any? hedgehogs [
    array:set hedgehog-data 1 sum [mass] of hedgehogs
    array:set hedgehog-data 2 mean [mass] of hedgehogs
    array:set hedgehog-data 3 sum [distance-traveled] of hedgehogs
    array:set hedgehog-data 4 mean [distance-traveled] of hedgehogs
    array:set hedgehog-data 5 count hedgehogs
  ] [
    array:set hedgehog-data 1 0
    array:set hedgehog-data 2 0
    array:set hedgehog-data 3 0
    array:set hedgehog-data 4 0
    array:set hedgehog-data 5 0
  ]
end

to export-data
  let file-path "results//hedgehog-data.csv"
  if not file-exists? file-path [
    file-open file-path
    file-print "Tick,Total Mass,Average Mass,Total Distance,Average Distance,Hedgehog Count"
    file-close
  ]
  file-open file-path
  file-print (word array:item hedgehog-data 0 "," array:item hedgehog-data 1 "," array:item hedgehog-data 2 "," array:item hedgehog-data 3 "," array:item hedgehog-data 4 "," array:item hedgehog-data 5)
  file-close
end


to draw-heatmap
  ask patches [
  if visit-count > 0 [
        set pcolor scale-color red visit-count 0 (max [visit-count] of patches)
      ]
  ]
end

to restore-original-colors ;;to tymczasowe rozwiązanie, w przyszłości pewnie szybciej będzie wczytać mapę na nowo
  ask patches [
    set pcolor og-color
  ]
  ask hedgehogs [
    if nest != 0 [ ask nest [ set pcolor brown ] ]
  ]
end

to export-result-map
  no-display
  ask turtles [ hide-turtle ]
  ask links [ hide-link ]

  draw-heatmap
  export-view "results//result-map.png"
  export-legend

  restore-original-colors

  ask turtles [ show-turtle ]
  ask links [ show-link ]
  display
end

to export-legend
  let max-visit-count max [visit-count] of patches
  file-open "results//legend.csv"
  file-print "Color,Visits,Percentage"
  ask patches [
    if visit-count > 0 [
      let color-value scale-color red visit-count 0 max-visit-count
      let percentage (visit-count / max-visit-count) * 100
      file-print (word color-value "," visit-count "," percentage)
    ]
  ]
  file-close
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Sprawdzenie wgranej mapy ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to count-unique-colors
  let unique-colors []
  ask patches [
    let pcolor-value pcolor
    if not member? pcolor-value unique-colors [
      set unique-colors lput pcolor-value unique-colors
    ]
  ]
  let number-of-unique-colors length unique-colors
  print (word "Number of unique colors: " number-of-unique-colors)
end
@#$#@#$#@
GRAPHICS-WINDOW
239
24
1102
486
-1
-1
3.0
1
10
1
1
1
0
0
0
1
0
284
0
150
0
0
1
ticks
30.0

BUTTON
48
63
111
96
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
59
478
180
511
clear everything
ask hedgehogs [ die ]\nca\nif file-exists? \"results//hedgehog-data.csv\" [ file-delete \"results//hedgehog-data.csv\" ]\nif file-exists? \"results//legend.csv\" [ file-delete \"results//legend.csv\" ]\nif file-exists? \"results//result-map.png\" [ file-delete \"results//result-map.png\" ]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
121
63
210
96
NIL
next-night
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
54
219
166
252
NIL
draw-heatmap
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
55
264
165
297
clear heatmap
restore-original-colors\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
235
525
327
570
Average Mass
array:item hedgehog-data 2
2
1
11

MONITOR
342
526
453
571
Average Distance
array:item hedgehog-data 4
2
1
11

MONITOR
465
526
571
571
Hedgehog Count
array:item hedgehog-data 5
0
1
11

BUTTON
56
311
165
344
export results
export-result-map
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1148
234
1482
359
Średnia masa jeży podczas symulacji
Noc
Masa (g)
0.0
10.0
0.0
10.0
true
false
"set-current-plot \"Średnia masa jeży podczas symulacji\"\nset-current-plot-pen \"avg-mass\"\n" "ifelse any? hedgehogs [\n  plot mean [mass] of hedgehogs\n] [ plot 0 ]\n"
PENS
"avg-mass" 1.0 0 -16777216 true "" "ifelse any? hedgehogs [\n  plot mean [mass] of hedgehogs\n] [ plot 0 ]\n"

MONITOR
1327
46
1499
91
Frontowym domu blizniaczego
time-percent-in-env \"ogrod-frontowy-domu-blizniaczego\"
2
1
11

MONITOR
1143
105
1313
150
Tylnym domu wolnostojącego
time-percent-in-env \"ogrod-tylny-domu-wolnostojacego\"
2
1
11

MONITOR
1325
106
1500
151
Frontowym domu wolnostojącego
time-percent-in-env \"ogrod-frontowy-domu-wolnostojacego\"
2
1
11

TEXTBOX
1146
14
1296
32
Procent czasu w ogrodzie:
12
0.0
1

MONITOR
1144
46
1313
91
Tylnym domu bliźniaczego
time-percent-in-env \"ogrod-tylny-domu-blizniaczego\"
2
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

zamiast akcji "go-to-nest" zcentralizować powrót do gniazda i budowę gniazda w funkcji "go" ?

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
