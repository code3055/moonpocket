# MoonPocket consumer example

This is a separate MoonBit module that depends on `code3055/moonpocket` `0.2.0`.

```powershell
moon install
moon run --target js main.mbt
```

It calls the typed `compare_schedules` API directly; it does not invoke the MoonPocket CLI or decode JSON.
