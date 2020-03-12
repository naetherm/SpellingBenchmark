// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.split;

import std.conv;
import std.random: Random;
import std.uni;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.nlp.hyphenator;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * HyphenationSplitError
 *
 * @brief
 * Splits the currently observed word according to syllabification rules.
 */
class HyphenationSplitError : ErrorInterface {

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
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if (NoiserUtility.isHyphenationEditable(cSent.errors[rW]) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW]) &&
        NoiserUtility.correctMinLength(cSent.tokens[rW], 2)) {
      auto syllables = this.mpLanguage.getHyphenator().hyphenate(to!string(cSent.tokens[rW]), "-");

      if (syllables.length >= 2) {
        ulong rHyphen = NoiserUtility.getRandomPosition(1, syllables.length - 1, this.mRnd);

        dstring first = "";
        dstring second = "";

        foreach (h; syllables[0..rHyphen])
          first ~= to!dstring(h);
        foreach (h; syllables[rHyphen..$])
          second ~= to!dstring(h);

        // Add the same word at the next position
        cSent.addTokenAfter(rW, second, cSent.spaces[rW], ErrorTypes.SPLIT, MarkTypes.END);
        cSent.tokens[rW] = first;
        cSent.spaces[rW] = true; // The previous element will now have a space
        cSent.errors[rW] = ErrorTypes.SPLIT; // Correct the error type
        cSent.setTokenMark(rW, MarkTypes.START);
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
 * RandomSplitError
 *
 * @brief
 * Adds a random split.
 */
class RandomSplitError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    //this.mHyphenator = noiser.mHyphenator;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if ((cSent.tokens[rW].length > 3) &&
        NoiserUtility.isHyphenationEditable(cSent.errors[rW]) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW]) &&
        NoiserUtility.correctMinLength(cSent.tokens[rW], 2)) {
      ulong nPos = NoiserUtility.getRandomPosition(1, cSent.tokens[rW].length - 2, this.mRnd);
      dstring rToken = cSent.tokens[rW].dup;

      dstring first = rToken[0..nPos];
      dstring second = rToken[nPos..$];

      // Add the same word at the next position
      cSent.addTokenAfter(rW, second, cSent.spaces[rW], ErrorTypes.SPLIT, MarkTypes.END);
      cSent.tokens[rW] = first;
      cSent.spaces[rW] = true; // The previous element will now have a space
      cSent.errors[rW] = ErrorTypes.SPLIT; // Correct the error type
      cSent.setTokenMark(rW, MarkTypes.START);
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
 * MultiRandomSplitError
 *
 * @brief
 * Makes a "multi-split". Thereby the observed word will be split into
 * the single characters.
 */
class MultiRandomSplitError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    //this.mHyphenator = noiser.mHyphenator;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if ((cSent.tokens[rW].length > 3) &&
        NoiserUtility.isHyphenationEditable(cSent.errors[rW]) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW]) &&
        NoiserUtility.correctMinLength(cSent.tokens[rW], 2)) {
      //ulong nPos = NoiserUtility.getRandomPosition(1, cSent.tokens[rW].length - 2, this.mRnd);
      dstring rToken = cSent.tokens[rW].dup;

      auto nTokenLen = rToken.length;

      // Add the same word at the next position
      cSent.addTokenAfter(rW, rToken[nTokenLen-1..$], cSent.spaces[rW], ErrorTypes.SPLIT, MarkTypes.END);
      for (size_t l = nTokenLen-2; l >= 1; l--) {
        cSent.addTokenAfter(rW, rToken[l..l+1], true, ErrorTypes.SPLIT, MarkTypes.INNER);
      }

      cSent.tokens[rW] = rToken[0..1];
      cSent.spaces[rW] = true; // The previous element will now have a space
      cSent.errors[rW] = ErrorTypes.SPLIT; // Correct the error type
      cSent.setTokenMark(rW, MarkTypes.START);
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
  /** The current langauge **/
  Language mpLanguage;
}
