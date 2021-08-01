// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.punctuation;

import std.conv;
import std.random: Random, uniform;
import std.stdio;
import std.string;
import std.uni;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * PunctuationError
 *
 * @brief
 * Randomizes the punctuation.
 */
class PunctuationError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if (NoiserUtility.IsEditable(cSent.errors[rW], bFurtherDestruction) &&
        NoiserUtility.IsEditablePunctionation(cSent.tokens[rW])) {
      dstring sToken = cSent.tokens[rW].dup;

      immutable dstring group = NoiserUtility.getLogicPunctuationGroup(sToken);
      auto rndPunc = to!dstring(group[uniform(0, $, this.mRnd)]);

      if (sToken != rndPunc) {
        cSent.errors[rW] = ErrorTypes.PUNCTUATION;
        cSent.tokens[rW] = rndPunc;
        cSent.setTokenMark(rW, MarkTypes.SINGLE);
      }
      if (cSent.tokens[rW] is cSent.initials[rW]) {
        cSent.errors[rW] = ErrorTypes.NONE;
      }

    }

    return cSent;
  }

  Random mRnd;
}

class AddCommaError : ErrorInterface {

  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
  }

  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {

    // Choose random position to insert a comma
    return cSent;
  }

  Random mRnd;
}


class RemoveCommaError : ErrorInterface {

  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
  }

  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {

    // Check if a comma exists within the sentence
    ulong[] positions = NoiserUtility.getCommaPosiions(cSent);

    if (positions.length > 0) {
      ulong rW = NoiserUtility.getRandomPosition(0, positions.length - 1, this.mRnd);
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
}

class CommaPlacementError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    // Is the current token of type ,
    if (NoiserUtility.IsEditable(cSent.errors[rW], bFurtherDestruction) &&
        (cSent.tokens[rW].length == 1) && 
        (cSent.tokens[rW][0] == ',')) {
      cSent.errors[rW] = ErrorTypes.PUNCTUATION;
      cSent.tokens[rW] = ""; // Remove the comma
      cSent.setTokenMark(rW, MarkTypes.SINGLE);
    } else if (cSent.marks[rW] == MarkTypes.NONE) {
      // Is the current word a conjunction?
      if ((rW > 0) && 
          this.mpLanguage.isConjunction(cSent.tokens[rW]) &&
          !NoiserUtility.isPunctuationOnly(cSent.tokens[rW])) {
        // Fix the spacing of the previous token
        cSent.spaces[rW-1] = false;
        // Add a new token before the current one
        cSent.addTokenAfter(rW-1, to!dstring(","), true, ErrorTypes.PUNCTUATION, MarkTypes.SOURCE_ONLY);
      } else {
        if ((rW < (cSent.tokens.length-1)) && 
            this.mpLanguage.isConjunction(cSent.tokens[rW+1]) &&
            !NoiserUtility.isPunctuationOnly(cSent.tokens[rW+1])) {
          // Add a new token before the current one
          cSent.addTokenAfter(rW, to!dstring(","), true, ErrorTypes.PUNCTUATION, MarkTypes.SOURCE_ONLY);
          // Fix the spacing of the previous token
          cSent.spaces[rW] = false;
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
