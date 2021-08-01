// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.replace;

import std.conv;
import std.random: Random;
import std.uni;
import std.algorithm: canFind;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.utils.helper : NeighborRepresentation;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * CharReplaceError
 *
 * @brief
 * Replaces a character with another character.
 * There are no special rules, the replacement character is chosen randomly.
 */
class CharReplaceError : ErrorInterface {

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

      if (nPos is 0) {
        auto rndChar = NoiserUtility.GetRandomChar(this.mRnd);
        if (NoiserUtility.isRightNeighbourLower(rToken, 0)) {
          cSent.tokens[rW] = toLower(rndChar) ~ rToken[1..$];
        } else {
          cSent.tokens[rW] = toUpper(rndChar) ~ rToken[1..$];
        }

      } else if (nPos is (rToken.length - 1)) {
        // Check if the neighborhood of the position is lower or upper case
        auto rndChar = NoiserUtility.GetRandomChar(this.mRnd);
        if (NoiserUtility.isLeftNeighbourLower(rToken, nPos)) {
          cSent.tokens[rW] = rToken[0..rToken.length-1] ~ toLower(rndChar);
        } else {
          cSent.tokens[rW] = rToken[0..rToken.length-1] ~ toUpper(rndChar);
        }
      } else {
        auto rndChar = NoiserUtility.GetRandomChar(this.mRnd);
        if (NoiserUtility.isCurrentCharLower(rToken, nPos)) {
          cSent.tokens[rW] = rToken[0..nPos] ~ toLower(rndChar) ~ rToken[nPos+1..$];
        } else {
          cSent.tokens[rW] = rToken[0..nPos] ~ toUpper(rndChar) ~ rToken[nPos+1..$];
        }
      }
      if (cSent.tokens[rW] !is rToken) {
        if (std.uni.icmp(cSent.tokens[rW], rToken) == 0) {
          if (nPos is 0) {
            cSent.errors[rW] = ErrorTypes.CAPITALISATION;
          } else {
            cSent.errors[rW] = ErrorTypes.NON_WORD;
          }
        }
        // if the generated token now contains a hyphen make this a HYPHENATION
        else if ((!rToken.canFind('-')) && (cSent.tokens[rW].canFind('-'))) {
          cSent.errors[rW] = ErrorTypes.HYPHENATION;
        }
        else if (NoiserUtility.isWrongPronoun(this.mpLanguage, rToken, cSent.tokens[rW])) {
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
