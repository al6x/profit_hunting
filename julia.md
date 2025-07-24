

Flexible nice and clean syntax

Fast after loading

Interactive computations


Clicking on function to navigate to definition almost never work

Reloading report: WARNING: replacing module Report.

Using `map(groupby(df, [:period, :volg, :rfq])) do g` produces ERROR: ArgumentError: using map over GroupedDataFrames is reserved

No navigation from VS Code repl stack traces to editor

Stop promoting modularisation and developing with active module, it's just some nonsense that contributes zero to the result.

Clicking on function `report` doesnt' work

The whole module system is overengineered garbage.


vscodedisplay(means_vol_rf)
ds2 = ds[in.(ds.rfg, Ref([1,5])), :]