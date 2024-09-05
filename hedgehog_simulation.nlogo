__includes ["setup_world//setup_world.nls" "go_procedures//go_procedure.nls" "setup_world//data_and_interface.nls"]

extensions[qlearningextension array]

breed [hedgehogs hedgehog]
breed [hoglets hoglet]

globals [
  possible-actions possible-angles
  night-duration current-time current-month current-day episode-counter
  ;max-distance
  avg-mass std-dev low-mass-threshold high-mass-threshold
  hedgehog-memory
  hedgehog-data mortality-data
  hibernating

  fence street urban ;o to też można później uprościć
  environment-types
  avoided-patches available-patches
  timestamp
]

hedgehogs-own [
  sex age
  mass daily-mass-gain
  speed distance-traveled return-probability
  visited-patches last-heading stuck-count
  nest ;;mother
  flags
  remaining-days ;;dla samic ile dni ciąży zostało, dla samców ile dni odpoczynku zostało
  terrain-color food-here fence-ahead distance-to-nest stay-in-nest
  family-color
]

hoglets-own [
  sex age
  mass
  nest mother
  come-of-age-done
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
  setup-world-from-image "C:/Users/HARDPC/Documents/GitHub/Hedgehog_ABM/setup_world/maps/map.png" 896 824;285 151;285 151
  print "Image loaded"


  print "Setting up world"
  setup-world
  print "World setup completed" ;; <-- to się liczy najdłużej

  setup-variables
  print "Variables setup completed"

  setup-hedgehogs
  print "Hedgehogs setup completed"

  if file-exists? "results//hedgehog-data.csv" [ file-delete "results//hedgehog-data.csv" ]
  set hedgehog-data array:from-list n-values 11 [0]
  ;collect-hedgehog-data

  if file-exists? "results//mortality-data.csv" [ file-delete "results//mortality-data.csv" ]
  set mortality-data array:from-list n-values 10 [0]

  ; check-food
  print "=====> Setup completed. <====="
end

to setup-variables
  set night-duration 613  ;; 2.3m : 0.049 m/s  47 --> 8 * 60 * 60 s = 28800 s -> : 47
  set current-time 0
  set current-month 3
  set current-day 21
  set episode-counter 0
  set hibernating false

  ;set max-distance 20
  set possible-angles [0 45 90 135 180 225 270 315]
  set hedgehog-memory 10
  set avg-mass 846 ;;na razie dla samców
  set std-dev 319  ;;na razie dla samców
  set low-mass-threshold avg-mass * 0.6
  set high-mass-threshold avg-mass * 1.5

  set fence red
  set street black
  set urban yellow

  set environment-types ["garden-back-1" "garden-front-1" "garden-back-2" "garden-front-2" "lawn"]
  set avoided-patches (list fence street urban violet) ;;violet is for out-of-bounds
  set available-patches patches with [
    not member? pcolor avoided-patches
    and not any? neighbors4 with [member? pcolor avoided-patches]
  ]

  set timestamp (word
											
                substring date-and-time 16 19
                substring date-and-time 19 22
                substring date-and-time 22 27 "-"
                substring date-and-time 0 2 "-"
                substring date-and-time 3 5
                )
end

to setup-hedgehogs
  let total-count 42 + random 42

  create-hedgehogs round (0.7 * total-count) [
    set sex one-of [0 1] ;; samica=1
    set age random-normal 1095 730  ;; średnia 3 lata (1095 dni), odchylenie standardowe 2 lata (730 dni)
    set color ifelse-value (sex = 0) [brown - 2] [brown]
    set mass random-normal avg-mass std-dev
    set size 7
    move-to one-of available-patches ;;with [pcolor = turquoise]
    set nest patch-here
    ask nest [ set pcolor brown ]

    set daily-mass-gain 0
    set speed random-normal 1 0.02
    set distance-traveled 0
    set return-probability 0.05


    ;let nearest-nest min-one-of available-patches with [is-nest?] [distance self]
    ;set nest nearest-nest
    ;set nest one-of available-patches
    ;move-to nest
    ;set nest nobody
    set visited-patches (list patch-here)

    random-turn-hedgehog
    set flags []
    set remaining-days 0
    set last-heading heading
    set stuck-count 0
    set stay-in-nest false

    update-state-variables

    ;set family-color one-of base-colors
    ;set color family-color
  ]

  ask hedgehogs [
    qlearningextension:state-def ["terrain-color" "fence-ahead" "food-here" "mass" "distance-to-nest"]
    (qlearningextension:actions [forage] [eat-food] [go-to-nest])
    qlearningextension:reward [reward-func]
    qlearningextension:end-episode [isEndState] reset-episode
    qlearningextension:action-selection "e-greedy" [0.25 0.995]
    ;qlearningextension:action-selection-egreedy 0.75 "rate" 0.95
    qlearningextension:learning-rate 0.95
    qlearningextension:discount-factor 0.55
  ]

  create-hoglets round (0.3 * total-count) [
    set sex one-of [0 1]
    set color ifelse-value (sex = 0) [brown + 1] [brown + 3]
    set age 49
    ;set age 7 + random 43 ;;wiek od 1 tyg do 7 tyg
    set mass 200 + (age / 49) * 35 + random 20
    set size 4
    set mother one-of turtles with [age >= 50 and sex = 1] ;; +zabezpieczenie
    set nest [nest] of mother ;;
    move-to nest
    set come-of-age-done false

    ;set color [family-color] of mother
  ]
end

;;;;;;;;;;;;;;;;
;; to opisać? ;;
;;;;;;;;;;;;;;;;
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
  if member? "rotated-180" flags [ ;;sprawdz czy to potrzebne
    set penalty -100
  ]

  let reward 0
  (ifelse
    member? "eat-food-fail" flags [
       set penalty (-1 + penalty)
    ]
    member? "eat-food-big-fail" flags [
       set penalty (-50 + penalty)
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
       set reward (5 + penalty)
    ]
    member? "eat-food-big-success" flags [
       set reward (50 + penalty)
    ]
    member? "go-to-nest-success" flags [
       set reward (3 + penalty)
    ]
    member? "forage" flags [
       set reward (20 + penalty)
    ]
    [  set reward (0 + penalty) ]
  )
  if not member? patch-here visited-patches [
    set reward (reward + 20)
  ]
  report (reward + penalty)
end

;;;;;;;;;;;;;;;;;;
;; Time Passage ;;
;;;;;;;;;;;;;;;;;;

to reset-episode
  ifelse hibernating [
    ask hedgehogs [
      let nightly-loss random-normal 0.28 0.08  ;; Średnia 28% z odchyleniem standardowym 8%

      ;; Obliczenie procentowego ubytku na każdy dzień hibernacji
      let daily-loss-percentage nightly-loss / 120 ;;4 miesiace hibernują

      ;; Zmniejszenie masy jeża
      set mass mass * (1 - daily-loss-percentage)

      if (age < 365 and mass < 475) or (age >= 365 and mass < 700) [
        ;print word "too small mass during hibernation - died: " who
        let cause "hibernation"
        collect-mortality-data cause who
        kill-hedgehog
      ]
    ]
  ] [
    ask hedgehogs [
      give-birth

      let metabolic-loss 20 ;; constant metabolic loss per day: https://journals.biologists.com/jeb/article/220/3/460/18766/Daily-energy-expenditure-in-the-face-of-predation
      let distance-loss ((random-float 100 + 10) + (floor (distance-traveled / 100) * 30))
      set mass mass - (metabolic-loss + distance-loss)
      if mass < 100 [
       ;print word "too small mass - died: " who
        let cause "too small mass"
        collect-mortality-data cause who
        kill-hedgehog
      ]
      if age > 365 and mass > 100 and mass <= 450 [ ;;dla hibernacji to bedzie 700g/600g
        let survival-chance 0.9 * (mass - 100) / 350 ;;dla 100g umrze, dla 450g ma 90% przezyc
        if random-float 1 > survival-chance [
          ;print word "too small mass - died: " who
          let cause "too small mass"
          collect-mortality-data cause who
          kill-hedgehog
        ]
      ]
      if age > 2920 [ ;; ponad 8 lat
        let mortality-risk (age - 2920) / 3650 ;; ryzyko śmierci rośnie z wiekiem, do 1 przy 15 latach
        if random-float 1 < mortality-risk [
          ;print word "Died of old age: " age
          let cause "old age"
          collect-mortality-data cause who
          kill-hedgehog
        ]
      ]
    ]
  ]

  ask hoglets [
    set age age + 1
    if age >= 45 [ ;; osesek to 45 dni
      come-of-age
    ]
  ]

  update-graph
  collect-hedgehog-data

  if not any? turtles [
    user-message "Wszystkie jeże nie żyją. Symulacja została przerwana." ;;ok nic nie daje
    stop
  ]

  ask hedgehogs [   ;;reset hedgehogs variables
    set age age + 1
    set stay-in-nest false
    set distance-traveled 0
    set daily-mass-gain 0
    set return-probability 0.05
    ifelse remaining-days <= 0 [
      set remaining-days 0 ;; na wszelki
    ] [
      set remaining-days remaining-days - 1
    ]
  ]

  set current-time 0
  set episode-counter episode-counter + 1
  set current-day current-day + 1
  if current-day > 30 [
    renew-resources ;;trzeba dostosowac do sezonu
    check-hibernation
    set current-day 1
    set current-month current-month + 1
    if current-month > 12 [
      set current-month 1
    ]
  ]
  reset-ticks
end

to check-hibernation
  ifelse current-month >= 11 or current-month < 3 [
    set hibernating true
  ] [
    set hibernating false
  ]
end

to give-birth
  ask hedgehogs with [sex = 1 and remaining-days = 1] [
    print "time to give birth"
    let litter-size random-normal 5 1
    hatch-hoglets min list litter-size 10 [
      set sex one-of [0 1]
      set color ifelse-value (sex = 0) [brown + 1] [brown + 3]
      set age 0
      set mass 200 + random 35
      set size 4
      set mother myself
      set nest [nest] of myself
      set come-of-age-done false
    ]
    set remaining-days 50 ;; póki opiekuje się oseskami nie będzie się rozmnażać
  ]
end

to kill-hedgehog
  if nest != 0 [
      ask nest [ set pcolor og-color ]
    ]
  die
end

to come-of-age
  if not come-of-age-done [
    ask hoglets with [mother = [mother] of myself] [
      set come-of-age-done true
      if myself != nobody [
        let target-patch one-of ([neighbors] of nest)
        if target-patch != nobody and member? self available-patches [
          move-to target-patch
        ]
      ]
    ]
    ;;umiera 1/4 miotu
    let litter hoglets with [mother = [mother] of myself and age = [age] of myself]
    let num-to-die floor (count litter / 4)
    print num-to-die
    let sorted-litter sort-on [mass] litter
    ask turtle-set (sublist sorted-litter 0 num-to-die) [
      ;print word "Died during come-of-age: " [mass] of self
      let cause "come of age"
      collect-mortality-data cause who
      kill-hedgehog
    ]
  ]

  hatch-hedgehogs 1 [
    set sex [sex] of myself
    set age [age] of myself
    set color ifelse-value (sex = 0) [brown - 2] [brown]
    set size 7
    set mass [mass] of myself
    set nest 0

    set daily-mass-gain 0
    set speed random-normal 1 0.02
    set distance-traveled 0
    set return-probability 0.05
    set visited-patches (list patch-here)

    random-turn-hedgehog
    set flags []
    set remaining-days 0
    set last-heading heading
    set stuck-count 0
    set stay-in-nest false

    update-state-variables

    qlearningextension:state-def ["terrain-color" "fence-ahead" "food-here" "mass" "distance-to-nest"]
    (qlearningextension:actions [forage] [eat-food] [go-to-nest])
    qlearningextension:reward [reward-func]
    qlearningextension:end-episode [isEndState] reset-episode
    qlearningextension:action-selection "e-greedy" [0.25 0.995]
    qlearningextension:learning-rate 0.95
    qlearningextension:discount-factor 0.55
  ]

  die
end

to next-night
  while [not isEndState] [
    go
  ]
  reset-episode
end

to-report isEndState
  report current-time >= night-duration
end

to renew-resources
  print "Nature is healing..."
  ask patches [
    if member? self environment-types [
      set food food + random 5 + 3 ;;różne środowiska może z inną prędkością powinny?
      ;;trzeba tu jakos ograniczyc zeby nie odnawialo za duzo
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
261
10
1165
843
-1
-1
1.0
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
895
0
823
1
1
1
ticks
10.0

BUTTON
26
28
89
61
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
18
531
139
564
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
99
27
180
60
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
19
342
131
375
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
18
428
128
461
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
1451
80
1590
125
Average distance [m]
word \"Males: \" precision (array:item hedgehog-data 4) 2
2
1
11

MONITOR
1181
53
1297
98
Hedgehogs Count
(word count hedgehogs \" : \" count hoglets)
0
1
11

BUTTON
135
429
244
462
export map
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
1181
201
1515
326
Średnia masa dorosłych jeży podczas symulacji
Noc
Masa (g)
0.0
10.0
100.0
10.0
true
false
"set-current-plot \"Średnia masa dorosłych jeży podczas symulacji\"\nset-current-plot-pen \"avg-mass\"\n" ""
PENS
"avg-mass" 1.0 0 -16777216 true "" "\n"

MONITOR
1357
622
1529
667
Frontowym domu blizniaczego
time-percent-in-env \"garden-front-1\"
2
1
11

MONITOR
1173
681
1343
726
Tylnym domu wolnostojącego
time-percent-in-env \"garden-back-2\"
2
1
11

MONITOR
1355
682
1530
727
Frontowym domu wolnostojącego
time-percent-in-env \"garden-front-2\"
2
1
11

TEXTBOX
1176
590
1326
608
Procent czasu w ogrodzie:
12
0.0
1

MONITOR
1174
622
1343
667
Tylnym domu bliźniaczego
time-percent-in-env \"garden-back-1\"
2
1
11

BUTTON
99
68
180
101
run a week 
let counter 0\nwhile [counter < 7] [\n next-night\n set counter counter + 1\n]
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
1176
800
1265
833
NIL
check-food
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
18
378
207
411
NIL
draw-heatmap-with-threshold
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
17
258
176
303
Current Day:
word (item (current-month - 1) [\"January\" \"February\" \"March\" \"April\" \"May\" \"June\" \"July\" \"August\" \"September\" \"October\" \"November\" \"December\"]) \" \" current-day \n  (ifelse-value ((current-day mod 10) = 1 and (current-day != 11)) [\" st\"] \n    [ifelse-value ((current-day mod 10) = 2 and (current-day != 12)) [\" nd\"] \n      [ifelse-value ((current-day mod 10) = 3 and (current-day != 13)) [\" rd\"] [\" th\"]]])
0
1
11

MONITOR
1312
53
1436
98
Average mass [g]
(word (ifelse-value any? hedgehogs [ precision mean [mass] of hedgehogs 2 ] [ 0 ]) \" : \" (ifelse-value any? hoglets [ precision mean [mass] of hoglets 2 ] [ 0 ]))
2
1
11

BUTTON
98
110
182
143
run a month
let counter 0\nwhile [counter < 30] [\n next-night\n set counter counter + 1\n]
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
1451
53
1590
98
Average distance [m]
word \"Females: \" precision (array:item hedgehog-data 5) 2
2
1
11

BUTTON
99
158
188
191
run a year
let counter 0\nwhile [counter < (30 * 12)] [\n next-night\n set counter counter + 1\n]
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

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
