# Purpose
Solc 0.8.20 takes very long to run. I'd like to benchmark different versions to pick the fastest one.

# Task
Please make a table with columns Solc, time elapsed.
Then test all the versions of Solc from 0.8.17 through to 0.8.20
using something like.

```
rm -rf cache/
time forge build --solc 0.8.17
```
Note this flag might not work so please use whatever command allows you to set the solc version
Set your timeout to 10 minutes as they do take long. 