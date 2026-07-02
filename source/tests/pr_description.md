Since the Tide Watch project doesn't have an automated test suite setup, the newly added `testIsValidLongitude` unit tests can be manually verified via the following steps once the test framework is enabled/run locally:
1. Run the test suite via the standard Garmin Connect IQ Monkey C unit testing command.
2. Confirm that `testIsValidLongitude` successfully passes, validating that valid coordinates (-180.0 to 180.0) are correctly accepted and that invalid ones (e.g., 180.1, -180.1, 360.0) are appropriately rejected.

These tests add boundary validation testing for longitudes which were previously missing.
