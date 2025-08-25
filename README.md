# TAF-Perl

**TAF-Perl** (Test Automation Framework - Perl) is a basic, extensible test framework written in Perl. It serves as a launching pad for anyone looking to build their own test framework without starting from scratch.

## Features

- Simple, perl module test suite structure
- Easily extendable for custom test needs
- Starter scripts and examples included
- MIT Licensed for open-source use
- Has a section for adding code to build client software
- Has a section for adding code for backend setup (docserv, database)
- Good for client(s) to backend testing

### Possible Extensions
- Stress test suite
- Performance test suite
- Support for most any client→source test suite

## Notes

- Best for standalone testing where client and source reside on the same host.
- Not intended for distributed or multi-host setups (for now).
- `taf.pl` is a generic framework that calls predefined subroutines in your test suite. The framework only checks whether each function completes successfully or returns an error, giving full control to the test suite for its logic.
- The main framework calls the following subroutines in your test suite:
  - `PreTestSetup`
  - `TestSetup`
  - `TestRun`
  - `TestPost`
  - `TestCleanup`
- Run `perl taf.pl --help` to see available actions and command-line options.
- `taf.pl` can loop over test cases, threads, and iterations for a given thread count.

## Getting Started

1. **Clone the repository**
   ```bash
   git clone https://github.com/JonathanBMiller/taf-perl.git
   cd taf-perl
   ```

2. **Run the main driver**
   ```bash
   perl taf.pl --help
   ```

3. **Explore the template suite**
   - Copy the provided template to create your own test cases
   - Add new Perl modules or scripts to expand functionality

## Directory Structure

```
taf-perl/
├── taf.pl               # Main driver script
├── archive/             # Auto-created for run archive of results.
├── client_source/       # Where client java, C, C++, etc. can be stored
├── help/                # Usage/help text
├── libs/                # Script and test suite tools (Perl modules)
├── logs/                # Auto-created for run logs during test execution.
├── properties/          # User and test properties files
├── properties/examples/ # Example property files
├── results/             # Auto-created for storing run results
├── test_suites/         # Test suite modules (copy template.pm to start)
├── README.md            # Project documentation
└── LICENSE              # MIT License
```

## Examples

```bash
perl taf.pl --prop=./properties/examples/test_01.template_hello.properties
perl taf.pl --prop=./properties/examples/test_01.template_hello.properties --iter=1 --threads=2,128 --tools-debug --skip-test-setup --duration=10
```
- The first command runs a test using a sample property file.
- The second command runs with more options: number of iterations, thread count, debug, skipping setup, and setting duration.

=======
## Test Suite Main TAF sub function calls
- BuildClient
- GetDefaultTests
- GetLegalTests
- GetTestClientVersion
- GetTestDuration
- GetTestSuiteRevision
- GetTestSuiteVersion
- GetThreads
- Help
- InstancesEnabled
- MultiThreadEnabled
- PreTestSetup
- StrictTestValidation
- TestCleanup
- TestPost
- TestRun
- TestSetup
- TSParseProperty

Of course, the test suite pm can have tons of private sub functions....

## Contributing

Contributions, suggestions, and feedback are welcome!  
Feel free to submit issues or pull requests to help improve this framework.

## Feedback

Your feedback is welcome! Please share your suggestions, ideas, and bug reports to help improve TAF-Perl.  
I appreciate constructive input—please keep it friendly and supportive.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

*TAF-Perl is a starting point—take it, build on it, and make it your own!*