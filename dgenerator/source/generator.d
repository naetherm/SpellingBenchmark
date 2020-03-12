// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.generator;

import std.stdio;
import std.container;
import std.variant;
import darg;
import snck: snck;

/**
 * @struct
 * Options
 *
 * @brief
 * Simple structure containing all options for the command line.
 */
struct Options {
    @Option("help", "h")
    @Help("Prints this help.")
    OptionFlag help;

    @Option("mode", "m")
    @Help("The mode to use. One one: deprecated, full_benchmark, medium_benchmark, tiny_benchmark.")
    string mode;

    @Option("input_dir", "i")
    @Help("The input directory.")
    string input_dir;

    @Option("output_dir", "o")
    @Help("The output directory.")
    string output_dir;

    @Option("data_dir", "d")
    @Help("The data directory.")
    string data_dir;

    @Option("dataset", "t")
    @Help("The dataset to work on.")
    string dataset;

    @Option("lang_code", "l")
    @Help("The language code to use.")
    string lang_code;

    @Option("seed", "s")
    @Help("The seed that should be used for all random generators.")
    int seed;

    @Option("format", "f")
    @Help("The format that to use during the generation of the benchmark data.")
    string format;

    @Option("selfcheck", "c")
    @Help("If activated, this flag is responsible for making a selfcheck.")
    bool selfcheck;

    @Option("trainingset", "x")
    @Help("If activated, a training set with the inverse set of the generated benchmarks will be generated as well.")
    bool trainingset;

    @Option("generate_langdict", "g")
    @Help("If activated we will generate a language dictionary out of the provided dataset.")
    bool generate_langdict;

    @Option("config", "y")
    @Help("The yaml configuration file to read.")
    string config;
}

immutable usage = usageString!Options("dgenerator");
immutable help = helpString!Options;

version (unittest) {
  // Required for unit testing, if not implemented this way two main routines would
  // be created
} else {

/**
 * @brief
 * Main routine.
 */
int main(string[] args) {
  Options parser;

  try {
    parser = parseArgs!Options(args[1..$]);
  } catch (ArgParseError e) {
    writeln(e.msg);
    writeln(usage);
    return 1;
  } catch (ArgParseHelp e) {
    writeln(usage);
    writeln(help);
    return 0;
  }

  Variant[string] opts = [
    "mode": Variant(parser.mode),
    "input_dir": Variant(parser.input_dir),
    "output_dir": Variant(parser.output_dir),
    "data_dir": Variant(parser.data_dir),
    "dataset": Variant(parser.dataset),
    "lang_code": Variant(parser.lang_code),
    "seed": Variant(parser.seed),
    "selfcheck": Variant(parser.selfcheck),
    "format": Variant(parser.format),
    "trainingset": Variant(parser.trainingset),
    "generate_langdict": Variant(parser.generate_langdict),
    "config": Variant(parser.config)
  ];

  // Catched everything, now continue with the real program
  if (opts["dataset"].get!string == "wikipedia") {
    // Import dataset
    import dgenerator.dataset.wikipedia;
    writeln("Start working loop with Wikipedia dataset.");
    // Create instance
    Wikipedia ds = new Wikipedia(opts);
    // Start generation of errors
    ds.generate();
  } else {
    writeln("Unknown dataset: ", parser.dataset);
  }

  return 0;
}

}
