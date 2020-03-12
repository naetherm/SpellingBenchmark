// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.numerics;

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

class NumericError : ErrorInterface {

  void setUp(Noiser noiser, string sLangCode) {
    this.mRnd = noiser.mRnd;
  }

  ref SentenceRepresentation call(ref SentenceRepresentation cSent, bool bFurtherDestruction) {

    return cSent;
  }

  Random mRnd;
}
