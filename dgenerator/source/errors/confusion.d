// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.confusion;

import std.conv;
import std.algorithm;
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
 * RealWordConfusionError
 *
 * @brief
 * Replaces the current word by a near neighbor word frmo the language neighborhood
 * knowledge table (either by edit distance or phonetic similarity).
 */
class RealWordConfusionError : ErrorInterface {

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

    if (NoiserUtility.IsEditable(cSent.errors[rW], bFurtherDestruction) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW])) {
      dstring rToken = cSent.tokens[rW].dup;

      // Is the work located within the language dictionary?
      //if (to!string(rToken) in this.mKey2N) {
      if (this.mpLanguage.isKeyInNeighbourhood(rToken)) {
        //auto r = this.mKey2N[to!string(rToken)];
        auto r = this.mpLanguage.getNeighbourhoodByKey(rToken);
        if (r.reals.length >= 2) {
          ulong rN = NoiserUtility.getRandomPosition(0, r.reals.length - 1, this.mRnd);
          ulong nNeighbor = r.reals[rN];

          //if (nNeighbor in this.mId2N) {
          if (this.mpLanguage.isIdInNeighbourhood(nNeighbor)) {
            //auto nn = this.mId2N[nNeighbor];
            auto nn = this.mpLanguage.getNeighbourhoodById(nNeighbor);

            if (nn.eType == "REAL_WORD")
              if (NoiserUtility.isWrongPronoun(this.mpLanguage, cSent.tokens[rW], to!dstring(nn.key))) {
                cSent.errors[rW] = ErrorTypes.MENTION_MISMATCH;
              }
              else {
                cSent.errors[rW] = ErrorTypes.REAL_WORD;
              }
            else
              cSent.errors[rW] = ErrorTypes.NON_WORD;
            cSent.tokens[rW] = to!dstring(nn.key);
            cSent.setTokenMark(rW, MarkTypes.SINGLE);
          }
        }
      }
    }

    if (cSent.tokens[rW] is cSent.initials[rW]) {
      cSent.errors[rW] = ErrorTypes.NONE;
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
  /** The current langauge **/
  Language mpLanguage;
}

class RealWordErrorConfusionError : ErrorInterface {

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

    if (NoiserUtility.IsEditable(cSent.errors[rW], bFurtherDestruction) &&
        !NoiserUtility.IsEditablePunctionation(cSent.tokens[rW])) {
      dstring rToken = cSent.tokens[rW].dup;

      // Is the work located within the language dictionary?
      //if (to!string(rToken) in this.mKey2N) {
      if (this.mpLanguage.isKeyInNeighbourhood(rToken)) {
        //auto r = this.mKey2N[to!string(rToken)];
        auto r = this.mpLanguage.getNeighbourhoodByKey(rToken);
        if (r.errors.length >= 2) {
          ulong rN = NoiserUtility.getRandomPosition(0, r.errors.length - 1, this.mRnd);
          ulong nNeighbor = r.errors[rN];

          //if (nNeighbor in this.mId2N) {
          if (this.mpLanguage.isIdInNeighbourhood(nNeighbor)) {
            //auto nn = this.mId2N[nNeighbor];
            auto nn = this.mpLanguage.getNeighbourhoodById(nNeighbor);

            if (!nn.key.canFind(" ") && all!isAlpha(nn.key)) {
              if (nn.eType == "REAL_WORD")
                if (NoiserUtility.isWrongPronoun(this.mpLanguage, cSent.tokens[rW], to!dstring(nn.key))) {
                  cSent.errors[rW] = ErrorTypes.MENTION_MISMATCH;
                }
                else {
                  cSent.errors[rW] = ErrorTypes.REAL_WORD;
                }
              else {
                if (nn.eType == "ARCHAIC") {
                  cSent.errors[rW] = ErrorTypes.ARCHAIC;
                } else {
                  cSent.errors[rW] = ErrorTypes.NON_WORD;
                }
              }
              cSent.tokens[rW] = to!dstring(nn.key);
              cSent.setTokenMark(rW, MarkTypes.SINGLE);
            }
          }
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
