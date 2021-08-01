// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.capitalisation;

import std.conv;
import std.random: Random;
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
 * WordCapitalisationError
 *
 * @brief
 * Deals with the capitalisation of randomly picked word.
 * There are several possible modes:
 * 1) The word is already capitalized -> make the first letter lower case
 * 2) The word is lower case -> capitalize the word
 * 3) The whole word is upper case -> make the whole word lower case
 */
class WordCapitalisationError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
  }

  /**
   * @brief
   *
   */
  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {
    static import std.ascii;
    // Get random position
    ulong rW = NoiserUtility.getRandomPosition(0, cSent.getNumCurrentTokens() - 1, this.mRnd);

    if (NoiserUtility.IsEditable(cSent.errors[rW], bFurtherDestruction) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW]) &&
        !NoiserUtility.isNumeric(cSent.tokens[rW])) {
      dstring sToken = cSent.tokens[rW].dup;
      if (sToken.length == 0) {
      }
      else if (sToken.length == 1) {
        if (NoiserUtility.isCurrentCharLower(sToken, 0)) {
          cSent.tokens[rW] = to!dstring(toUpper(sToken[0]));
        } else {
          cSent.tokens[rW] = to!dstring(toLower(sToken[0]));
        }
      } else {
        if (NoiserUtility.isCurrentCharLower(sToken, 0)) {
          cSent.tokens[rW] = to!dstring(asCapitalized(sToken));
        } else {
          if (NoiserUtility.isAllUpper(sToken)) {
            cSent.tokens[rW] = to!dstring(asLowerCase(sToken));
          } else {
            cSent.tokens[rW] = to!dstring(toLower(sToken[0])) ~ sToken[1..$];
          }
        }
      }

      cSent.errors[rW] = ErrorTypes.CAPITALISATION;

      if (cSent.tokens[rW] is cSent.initials[rW]) {
        cSent.errors[rW] = ErrorTypes.NONE;
      }
      
      cSent.setTokenMark(rW, MarkTypes.SINGLE);
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
}
