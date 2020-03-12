// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.hyphenation;

import std.conv;
import std.random: Random;
import std.uni;
import std.string;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.nlp.hyphenator;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * WordHyphenationError
 *
 * @brief
 * Adds a hyphen into the currently observed word. Thereby the hyphen is not
 * added randomly, but the rules of syllabification are taken into consideration.
 */
class WordHyphenationError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {
    // First branch: Search in all tokens if we find one that is length > 1 and
    // contains a hyphen without being already an induced highenation error
    for (size_t i = 0; i < cSent.getNumCurrentTokens(); ++i) {
      if ((cSent.tokens[i].length > 1) && (indexOf(cSent.tokens[i], '-') != -1) && (cSent.errors[i] == ErrorTypes.NONE)) {
        cSent.tokens[i] = cSent.tokens[i].replace("-", "");
        cSent.errors[i] = ErrorTypes.HYPHENATION; // TODO(naetherm): MISSING_HYPHENATION
        cSent.setTokenMark(i, MarkTypes.SINGLE);
        break;
      }
    }

    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if (NoiserUtility.isHyphenationEditable(cSent.errors[rW]) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW]) &&
        NoiserUtility.correctMinLength(cSent.tokens[rW], 2)) {
      auto syllables = this.mpLanguage.getHyphenator().hyphenate(to!string(cSent.tokens[rW]), "-");

      if (syllables.length >= 2) {
        ulong rHyphen = NoiserUtility.getRandomPosition(1, syllables.length - 1, this.mRnd);

        dstring prefix = "";
        dstring suffix = "";

        foreach (h; syllables[0..rHyphen])
          prefix ~= to!dstring(h);
        foreach (h; syllables[rHyphen..$])
          suffix ~= to!dstring(h);

        if (cSent.tokens[rW] != prefix ~ "-" ~ suffix) {
          cSent.tokens[rW] = prefix ~ "-" ~ suffix;
          cSent.errors[rW] = ErrorTypes.HYPHENATION; // TODO(naetherm): HYPHENATION
          cSent.setTokenMark(rW, MarkTypes.SINGLE);
        }
      }
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
  /** The current langauge **/
  Language mpLanguage;
}

/**
 * @class
 * WordRemoveHyphenationError
 *
 * @brief
 * If the word contains a hyphen, because its a compound word remove that hyphen
 * and create a single word out of both words.
 */
class WordRemoveHyphenationError : ErrorInterface {

  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {
    // First branch: Search in all tokens if we find one that is length > 1 and
    // contains a hyphen without being already an induced highenation error
    for (size_t i = 0; i < cSent.getNumCurrentTokens(); ++i) {
      if ((cSent.tokens[i].length > 1) && (indexOf(cSent.tokens[i], '-') != -1) && 
          NoiserUtility.IsEditable(cSent.errors[i], false)) {
        cSent.tokens[i] = cSent.tokens[i].replace("-", "");
        cSent.errors[i] = ErrorTypes.COMPOUND_HYPHEN;
        cSent.setTokenMark(i, MarkTypes.SINGLE);
        break;
      }
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
  //Hyphenator mHyphenator;
  Language mpLanguage;
}
