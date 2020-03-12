// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.tense;

import std.conv;
import std.random: Random;
import std.uni;

import dgenerator.utils.helper: SentenceRepresentation;
import dgenerator.errors.utility: NoiserUtility;
import dgenerator.utils.helper : NeighborRepresentation;
import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.types;
import dgenerator.nlp.language: Language;
import dgenerator.nlp.nlp;
import dgenerator.errors.error: ErrorInterface;

/**
 * @class
 * TenseError
 *
 * @brief
 * This error generation class is capable of producing tense errors.
 */
class TenseError : ErrorInterface {

  /** Setup **/
  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
    this.mpLanguage = noiser.mlstLanguages[sLangCode];
  }

  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {
    // First let's loop through all tokens of the sentence and collect which one is a verb at all
    ulong[] lstIndices;

    // First loop through the sentence and try to find all verbs, if there are multiple
    for (ulong i = 0; i < cSent.getNumCurrentTokens(); ++i) {
      if (this.mpLanguage.isVerb(cSent.tokens[i])) {
        lstIndices ~= i;
      }
    }

    // If just a single verb was found get a randomized verb and apply a randomized tense form on it
    if (lstIndices.length == 1) {
      auto idx = lstIndices[0];

      VerbTenses cRndTense = to!VerbTenses(NoiserUtility.getRandomPosition(0, to!int(VerbTenses.max) - 1, this.mRnd));
      while ((cRndTense == this.mpLanguage.verbTense(cSent.tokens[idx])) &&
             (this.mpLanguage.verbGetTense(cSent.tokens[idx], cRndTense, false) != "")) {
        cRndTense = to!VerbTenses(NoiserUtility.getRandomPosition(0, to!int(VerbTenses.max) - 1, this.mRnd));
      }

      auto conjugated = this.mpLanguage.verbGetTense(cSent.tokens[idx], cRndTense, false);


      if (conjugated != "") {
        if (conjugated != cSent.tokens[idx]) {
          cSent.errors[idx] = ErrorTypes.TENSE;
        }
        cSent.tokens[idx] = conjugated;
      }
    } else if (lstIndices.length > 1) {
      auto idx = lstIndices[NoiserUtility.getRandomPosition(0, lstIndices.length - 1, this.mRnd)];

      VerbTenses cRndTense = to!VerbTenses(NoiserUtility.getRandomPosition(0, to!int(VerbTenses.max) - 1, this.mRnd));
      while ((cRndTense == this.mpLanguage.verbTense(cSent.tokens[idx])) &&
             (this.mpLanguage.verbGetTense(cSent.tokens[idx], cRndTense, false) != "")) {
        cRndTense = to!VerbTenses(NoiserUtility.getRandomPosition(0, to!int(VerbTenses.max) - 1, this.mRnd));
      }

      auto conjugated = this.mpLanguage.verbGetTense(cSent.tokens[idx], cRndTense, false);

      if (conjugated != "") {
        if (conjugated != cSent.tokens[idx]) {
          cSent.errors[idx] = ErrorTypes.TENSE;
        }
        cSent.tokens[idx] = conjugated;
      }
    }

    return cSent;
  }

  /** Random generator **/
  Random mRnd;
  /** The current langauge **/
  Language mpLanguage;

}
