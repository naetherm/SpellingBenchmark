// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.insert;

import std.conv;
import std.random: Random;
import std.uni;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.utils.helper : NeighborRepresentation;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * CharInsertError
 *
 * @brief
 * This specific implementation does nothing to the incoming sentence.
 * The sentence will be returned as it is.
 */
class CharInsertError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  /**
   * @brief
   * Does nothing.
   */
  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if (NoiserUtility.IsEditable(cSent.errors[rW], bFurtherDestruction) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW]) &&
        NoiserUtility.correctMinLength(cSent.tokens[rW], 2)) {
      ulong nPos = NoiserUtility.getRandomPosition(0, cSent.tokens[rW].length - 1, this.mRnd);

      dstring rToken = cSent.tokens[rW].dup;

      auto c = NoiserUtility.GetRandomChar(this.mRnd);
      if (nPos is 0) {
        if (NoiserUtility.isCurrentCharLower(rToken, 0)) {
          cSent.tokens[rW] = to!dstring(c) ~ rToken;
        } else if (NoiserUtility.isAllUpper(rToken)) {
          cSent.tokens[rW] = to!dstring(toUpper(c)) ~ rToken[0..$];
        } else {
          cSent.tokens[rW] = to!dstring(c) ~ toLower(rToken[0]) ~ rToken[1..$];
        }

      } else if (nPos is (rToken.length - 1)) {
        if (NoiserUtility.isAllUpper(rToken)) {
          cSent.tokens[rW] = rToken ~ to!dstring(toUpper(c));
        } else {
          cSent.tokens[rW] = rToken ~ to!dstring(toLower(c));
        }

      } else {
        if (NoiserUtility.isAllUpper(rToken)) {
          cSent.tokens[rW] = rToken[0..nPos] ~ toUpper(c) ~ rToken[nPos..$];
        } else if (NoiserUtility.areNeighbouringCharsLower(rToken, nPos)) {
          cSent.tokens[rW] = rToken[0..nPos] ~ toLower(c) ~ rToken[nPos..$];
        } else {
          cSent.tokens[rW] = rToken[0..nPos] ~ c ~ rToken[nPos..$];
        }
      }
      if (cSent.tokens[rW] !is rToken) {
        if (NoiserUtility.isWrongPronoun(this.mpLanguage, rToken, cSent.tokens[rW])) {
          cSent.errors[rW] = ErrorTypes.MENTION_MISMATCH;
        }
        else if (NoiserUtility.inLangDict(cSent.tokens[rW], this.mpLanguage.getKeyNeighbourhood()))
          cSent.errors[rW] = ErrorTypes.REAL_WORD;
        else
          cSent.errors[rW] = ErrorTypes.NON_WORD;
      }
      if (cSent.tokens[rW] is cSent.initials[rW]) {
        cSent.errors[rW] = ErrorTypes.NONE;
      }
      cSent.setTokenMark(rW, MarkTypes.SINGLE);
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
  /** The current langauge **/
  Language mpLanguage;
}
