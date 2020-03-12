// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.nlp.nlp;

import std.container: Array;
import std.stdio;
import std.conv;
import std.file: readText, FileException;
import std.json;
import std.path;
import std.string;
import std.algorithm: canFind;

/**
 * @class
 * Dictionary
 *
 * @brief
 * Very basic dictionary that can represent any list of types.
 */
class Dictionary {

  this(string sDataDir, string sLangCode, int nColumnOfInterest, char cDelimiter) {
    this.msDataDir = sDataDir;
    this.msLangCode = sLangCode;
    this.mcDelimiter = cDelimiter;
    this.mnColumnOfInterest = nColumnOfInterest;

    // Read all important information
    this.readIn();
  }

  private void readIn() {
    string[] readData = readText(buildPath(this.msDataDir, format("%s.bin", this.msLangCode))).split("\n");

    foreach(line; readData) {
      this.msData ~= to!dstring(line.split(this.mcDelimiter)[this.mnColumnOfInterest]);
    }
  }

  /**
   * @brief
   * Determines and returns whether a given word @p sWord is within this dictionary.
   *
   * @return
   * True if the given word can be found within this dictionary, false otherwise.
   */
  public bool contains(dstring sWord) {
    return this.msData.canFind(sWord);
  }

  private dstring[] msData;

  private string msDataDir;
  private string msLangCode;
  private char mcDelimiter;
  private int mnColumnOfInterest;
}


/**
 * @enum
 * Verbtenses
 *
 * @brief
 */
enum VerbTenses {
  Infinitive = 0,
  FirstSingularPresent,
  SecondSingularPresent,
  ThirdSingularPresent,
  PresentPlural,
  PresentParticiple,
  FirstSingularPast,
  SecondSingularPast,
  ThirdSingularPast,
  PastPlural,
  Past,
  PastParticiple
}


/**
 * @class
 * VerbTable
 *
 * @brief
 */
class VerbTable {

  /**
   * @brief
   * Default constructor.
   */
  this(string sDataDir, string sLangCode) {
    this.msDataDir = sDataDir;
    this.msLangCode = sLangCode;

    // Read in the verb forms
    this.readIn();
  }

  /**
   * @brief
   * Basic check whether the given word @p sWord is a verb.
   *
   * @return
   * True if the given word is a known verb, false otherwise.
   */
  public bool isVerb(dstring sWord) {
    return ((sWord in this.mlstVerbLemmas) !is null);
  }

  /**
   * @brief
   * Returns the infinitive form of a verb, if it's known.
   *
   * @return
   * The infinitive form of a verb.
   */
  public dstring getInfinitive(dstring sWord) {
    if (sWord in this.mlstVerbLemmas) {
      return this.mlstVerbLemmas[sWord];
    }

    return "";
  }

  /**
   * @brief
   * This method will conjugate a given verb @p sWord to the verb tense @p cTense. One can further 
   * define whether the negated form should be returned, if there is any negated form available.
   * If now negation is available an empty string will be returned.
   *
   * @return
   * The conjugated form of the word @p sWord.
   */
  public dstring conjugate(dstring sWord, VerbTenses cTense, bool bNegate=false) {
    // First get the infinitive form
    auto infForm = this.getInfinitive(sWord);

    int nElementIdx = to!int(cTense);
    int nFinalIdx = nElementIdx;

    // The negated forms are appended at the end!
    if (bNegate) {
      nFinalIdx += to!int(VerbTenses.max);
    }

    if (this.mlstVerbTenses[infForm][nFinalIdx] != "") {
      return this.mlstVerbTenses[infForm][nFinalIdx];
    } else {
      return this.mlstVerbTenses[infForm][nElementIdx];
    }
  }

  public VerbTenses verbTense(dstring sWord) {
    // First get the "lemma"
    auto lemma = this.mlstVerbLemmas[sWord];

    for(size_t i = 0; i < VerbTenses.max; ++i) {
      if (this.mlstVerbTenses[lemma][i] == sWord) {
        return to!VerbTenses(i);
      }
    }

    return VerbTenses.Infinitive;
  }

  public dstring verbPresent(dstring sWord, VerbTenses cTense, bool bNegate=false) {
    auto sPresent = this.conjugate(sWord, cTense, bNegate);
    if (sPresent != "") {
      return sPresent;
    }

    return this.conjugate(sWord, VerbTenses.Infinitive, bNegate);
  }

  public dstring verbPast(dstring sWord, VerbTenses cTense, bool bNegate=false) {

    auto sPast = this.conjugate(sWord, cTense, bNegate);
    if (sPast != "") {
      return sPast;
    }

    return this.conjugate(sWord, VerbTenses.Past, bNegate);
  }

  public dstring verbPresentParticiple(dstring sWord) {
    return this.conjugate(sWord, VerbTenses.PresentParticiple);
  }

  public dstring getRandomTense(dstring sVerb) {
    auto currentTense = this.verbTense(sVerb);

    VerbTenses cTense = VerbTenses.Infinitive;

    return this.mlstVerbTenses[this.mlstVerbLemmas[sVerb]][to!int(cTense)];
  }

  /**
   * @brief
   * Reads the verb list and builds the conjugation and lemma table for all found verbs.
   */
  private void readIn() {
    ///
    /// The structure of each line of the file is:
    ///
    ///
    string[] verbs = readText(buildPath(to!string(this.msDataDir), format("%s.bin", this.msLangCode))).split("\n");

    // Now loop through all verbs (obviously not all verbs but the most ~10,000 common verbs)
    foreach(line; verbs) {
      string[] conjugations = line.split(',');

      auto baseForm = to!dstring(conjugations[0]);

      // Add verb to mlstVerbTenses
      this.mlstVerbTenses[baseForm] = to!(dstring[])(conjugations);

      // Create lemmas entries
      foreach(lemma; conjugations) {
        this.mlstVerbLemmas[to!dstring(lemma)] = baseForm;
      }
    }
  }

  /**
   * The data directory of the files.
   */
  private string msDataDir;

  /**
   * The language code of the language code to use.
   */
  private string msLangCode;

  /**
   * List of verb tenses
   */
  private dstring[][dstring] mlstVerbTenses;

  /**
   * List of verb lemmas
   */
  private dstring[dstring] mlstVerbLemmas;
}