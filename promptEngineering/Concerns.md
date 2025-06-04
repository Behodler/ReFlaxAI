1. Code is not compiling
2. _updateOracle() is called at the beginning and end of the deposit, withdraw and claim functions.
The update requires a certain amount of blocks to pass since the last update. It seems to me that only one update at the beginning is necessary. It should be noted that accuracy is not as important to me as robustness against manipulation.
