// Copyright 2019-2020, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.utils.config;

import std.string;
import dyaml;

/**
 * @class
 * Config
 *
 * @brief
 * YAML-based configuration file reader.
 * Currently the configuration file only supports the probability settings of all
 * error generators. If an error generated is not specified its probability will
 * be set to zero.
 */
class Config {
  /**
   * @brief
   * Constructor.
   *
   * @param [in]sConfigFile
   * The path to the configuration file to use.
   */
  this(string sConfigFile) {
    this.msConfigFile = sConfigFile;

    this.readIn();
  }


  /**
   * @brief
   * Reads the probabilities for all provided error generators.
   */
  void readIn() {
    // Load configuration file
    this.mcRoot = Loader.fromFile(this.msConfigFile).load();
  }

  /**
   * @brief
   * Returns the probability for error generator @p sGenName.
   *
   * @param [in]sGenName
   * The name of the generator.
   */
  float getProbabilityOfGenerator(string sGenName) {
    if (sGenName in this.mcRoot) {
      return this.mcRoot[sGenName].as!float;
    } else {
      // If not available deactive that generator
      return 0.0;
    }
  }

  /** The path to the configuration file **/
  string msConfigFile;
  /** The read YAML **/
  Node mcRoot;
}
