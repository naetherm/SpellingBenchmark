// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dutility.types;

import std.string;
import std.container.array;

/**
 * @enum
 * ErrorTypes
 *
 * @brief
 * Enumeration containing all error categories that are supported by the
 * error generator.
 *
 * @note(naetherm)
 * Think about outsourcing this to a utils library because we will need this
 * in the generator and evaluator.
 */
enum ErrorTypes {
  // Invalid, comparable with <PAD>
  //PAD = -1,
  // No error detected
  NONE = 0,
  // Non-word error
  NON_WORD = 1,
  // Real-word confusion
  REAL_WORD = 2,
  // Wrong splitting
  SPLIT = 3,
  // Hyphenation error
  HYPHENATION = 4,
  // Concatenation error
  CONCATENATION = 5,
  // Capitalisation error
  CAPITALISATION = 6,
  // Outdated spelling for a word
  ARCHAIC = 7,
  // Repeat a word twice
  REPEAT = 8,
  // Repeat a word twice
  PUNCTUATION = 9,
  // Personal pronoun errors like he <-> she
  PRONOUN = 10
}

/**
 * @brief
 * Helper method for type to string conversation.
 */
string TypeToName(ErrorTypes nType) {
  switch (nType) with (ErrorTypes) {
    //case PAD:
    //  return "PAD";
    case NONE:
      return "NONE";
    case NON_WORD:
      return "NON_WORD";
    case REAL_WORD:
      return "REAL_WORD";
    case SPLIT:
      return "SPLIT";
    case HYPHENATION:
      return "HYPHENATION";
    case CONCATENATION:
      return "CONCATENATION";
    case CAPITALISATION:
      return "CAPITALISATION";
    case ARCHAIC:
      return "ARCHAIC";
    case REPEAT:
      return "REPEAT";
    case PUNCTUATION:
      return "PUNCTUATION";
    case PRONOUN:
      return "PRONOUN";
    default:
      return "NONE";
  }
}

/**
 * @enum
 * MarkTypes
 *
 * @brief
 * Enumeration for marking structures within the SentenceRepresentation.
 */
enum MarkTypes {
  NONE = 0,

  SINGLE = 1,

  START = 2,

  INNER = 3,

  END = 4
}

/**
 * @brief
 * Helper method for type to string conversation.
 */
string MarkToName(MarkTypes nMark) {
  switch (nMark) with (MarkTypes) {
    case NONE:
      return "NONE";
    case SINGLE:
      return "SINGLE";
    case START:
      return "START";
    case INNER:
      return "INNER";
    case END:
      return "END";
    default:
      return "NONE";
  }
}
