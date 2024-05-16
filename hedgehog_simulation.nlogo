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