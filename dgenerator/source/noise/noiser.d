// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.noise.noiser;

import dgenerator.errors.error: ErrorInterface, ErrorWrapper;
import dgenerator.utils.types;
import dgenerator.nlp.hyphenator;
import dgenerator.nlp.gaussian_keyboard;
import dgenerator.utils.helper;
import dgenerator.nlp.language: Language;
import dgenerator.utils.config: Config;

import std.algorithm;
import std.container: Array;
import std.file: readText;
import std.path;
//import std.ascii;
import std.json;
import std.conv;
import std.random;
import std.string;
import std.stdio;
import std.uni;
import std.variant;

//import fast.json;

/**
 * @class
 * Noiser
 *
 * @brief
 * General noiser implementation. This class holds general information,
 * like the random seed, the gaussian keyboard, hyphenator and language
 * dictionary instance. All logic regarding the generation of errors
 * is outsourced to subclasses (see dgenerator.errors for that). Those
 * error generation classes are registered through the reflection system.
 */
class Noiser {
  /**
   * @brief
   * Constructor.
   *
   * @param [in]lstArgs
   * Array containing the additional arguments for noise generator.
   */
  this(Variant[string] lstArgs, Config cConfig) {
    this.lstArgs = lstArgs;
    this.config = cConfig;
    writeln(">> Set the seed to ", this.lstArgs["seed"].get!int);
    this.mRnd = Random(this.lstArgs["seed"].get!int);
    write(">> Initializing the gaussian keyboard ... ");
    this.mGK = this.initializeGaussianKeyboard(this.lstArgs["lang_code"].get!(string));
    writeln("\tDone.");
    write(format(">> Initializing all required data for the language '%s' ...", this.lstArgs["lang_code"].get!(string)));
    this.initializeLanguage(this.lstArgs["data_dir"].get!(string), this.lstArgs["lang_code"].get!(string));
    writeln("\tDone.");

    // Read in all error generator classes and call their setup method
    this.readReflectionInformation();

    writeln(">> Normalize callers");
    float sum = 0.0;
    foreach (caller; this.callers) {
      sum += caller.probability;
    }
    if (sum == 0.0) {
      sum = 1.0;
    }
    foreach (ref caller; this.callers) {
      caller.probability /= sum;
      this.caller_props ~= caller.probability;
    }
  }


  void readReflectionInformation() {
    float sum = 0.0;
    foreach (mod; ModuleInfo) {
      foreach (cls; mod.localClasses) {
        foreach (intf; cls.interfaces) {
          if (intf.classinfo.name.canFind("ErrorInterface")) {
            auto slimmedName = cls.name.split(".")[$-1];
            float fProb = this.config.getProbabilityOfGenerator(slimmedName);
            if (fProb <= 0.0) {
              writeln("Warning: A probability <= 0.0 will result in not calling that generator.");

              this.callers.insertBack(new ErrorWrapper(cls.create(), 0.0));
            } else {
              this.callers.insertBack(new ErrorWrapper(cls.create(), fProb));
            }
          }
        }
      }
    }
    foreach (ref caller; this.callers) {
      caller.wrapped.setUp(this, this.lstArgs["lang_code"].get!(string));
    }
  }

  //
  // Noise generation
  //

  /**
   * @brief
   * Simple method for noise generation.
   */
  SentenceRepresentation generateNoise(ulong aid, dstring sSentence) {
    // Generate the internally used representation
    SentenceRepresentation cSent = new SentenceRepresentation(aid, sSentence);

    if (this.lstArgs["selfcheck"].get!(bool) == true) {
      /// TODO(naetherm): Reconstruct the input sentence from the representation
      ///                 and compare with original input sentence
      dstring s = "";
      for (size_t i = 0; i < cSent.getNumInitialTokens(); ++i) {
        s ~= cSent.tokens[i];
        if (cSent.spaces[i]) {
          s~= " ";
        }
      }
      if (s != sSentence) {
        writeln("FATAL ERROR: Input sentence is not equal to generated representation:");
        writeln("\tExpected: ", sSentence);
        writeln("\tResult  : ", s);
      }
    }

    for (size_t t = 0; t < this.lstArgs["num_tries"].get!int; t++) {
      cSent = this.callers[dice(this.mRnd, this.caller_props)].call(
        cSent,
        this.lstArgs["allow_further_destroy"].get!(bool)
      );
    }

    return cSent;
  }

  //
  // Initialisation methods
  //

  private GaussianKeyboard initializeGaussianKeyboard(string sLangCode) {
    /// TODO(naetherm): Implement me!
    return new GaussianKeyboard(sLangCode);
  }

  /**
   * @brief
   * This method will read in all information for a specific language, given by @p sLangCode.
   *
   * @param [in]sDataDir
   * The data directory where all data is located.
   * @param [in]sLangCode
   * the language code to read in from the given data directory.
   */
  private void initializeLanguage(string sDataDir, string sLangCode) {
    // Hand in all data to the Language class
    Language pLanguage = new Language(sDataDir, sLangCode);

    // Add the loaded language to the associative language array
    this.mlstLanguages[sLangCode] = pLanguage;
  }

  private Variant[string] lstArgs;

  private Config config;

  /**
   * List of all propabilities -> after constructor this list is normalized..
   */
  private double[] mlstProbabilities;

  /**
   * Instance of the gaussian keyboard implementation.
   */
  public GaussianKeyboard mGK;
  /**
   * Our random number gnerator.
   */
  public Random mRnd;

  /**
   * Language dictionary.
   */
  private string[] mLangDict;

  /**
   * An associative array which can contain multiple different languages.
   */
  public Language[string] mlstLanguages;

  private Array!ErrorWrapper callers;
  private float[] caller_props;
}

unittest {
  writeln("========== NOISER TESTS ==========");
  string[string] args;
  args["data_dir"] = "/nfs/raid5/naetherm/PhD/repositories/mn1045/spellingcorrectionbenchmark/data";
  args["lang_code"] = "en_US";
  //Noiser n = new Noiser(args);

  //n.dup;
}
