// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.errors.error;

import std.algorithm;
import std.stdio;
import std.traits;

import dgenerator.noise.noiser: Noiser;
import dgenerator.utils.helper;

/**
 * @interface
 * ErrorInterface
 *
 * @brief
 * this interface should be used by all errors that can occur during
 * the generation. This interface has the method call which must be implemented
 * for each specific error type. Take a look into the other classes within
 * this module on how to use this interface.
 * If you need additional information from the noiser, like the currently
 * used language dictionary implement the standardised setUp method, as in
 * this example:
 *
 * ¢lass ComplexError : ErrorInterface {
 *   void setUp(ref Noiser noiser) {
 *     // Implement this
 *   }
 *   ref SentenceRepresentation call(ref SentenceRepresentation cSent) { // ... }
 * }
 *
 * We will automatically check during runtime of such a setUp method exist
 * and call it.
 */
interface ErrorInterface {
  /**
   * @brief
   * Caller for the specific error generation.
   */
  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return;

  /**
   * @brief
   * By default return a zero probability.
   *
   * @return
   * Returns a zero probability by default.
   */
  //float getProbability() {
  //  return 0.0;
  //}

  void setUp(Noiser noiser, string sLangCode);
}


/**
 * @class
 * ErrorWrapper
 *
 * @brief
 * Wrapper around a specific error generator, containing the calling probability of
 * that generator.
 */
class ErrorWrapper {

  this(T)(T cType, float fProbability = 0.0) {
    this.wrapped = cast(ErrorInterface)cType;

    this.probability = fProbability;

  }

  ref SentenceRepresentation call(return ref SentenceRepresentation cSent, bool bFurtherDestruction) return {
    return this.wrapped.call(cSent, bFurtherDestruction);
  }

  public ErrorInterface wrapped;

  public float probability;
}
