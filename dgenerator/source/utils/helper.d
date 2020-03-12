// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.utils.helper;

import dgenerator.utils.types;

import std.algorithm;
import std.container: Array;
import std.regex;
import std.string;
import std.uni;
import std.stdio;
import std.conv;

/**
 * @class
 * SourceRepresentation
 *
 * @brief
 * This is a simple representation for each element of the source sentence
 * input.
 */
class SourceRepresentation {
  /**
   * @brief
   * Constructor.
   */
  this(ulong aid, ulong nSid, ulong nId, dstring sToken, bool bSpace) {
    this.aid = aid;
    this.sid = nSid;
    this.id = nId;
    this.token = sToken;
    this.space = bSpace;
  }

  string asJson() {
    return format("  {\"id\": \"a%s.s%s.w%s\", \"token\": \"%s\", \"space\": %s}\n",
      this.aid,
      this.sid,
      this.id,
      to!string(this.token),
      this.space
    );
  }

  ulong aid; // Article ID
  ulong sid;
  ulong id;
  dstring token;
  bool space;
}

/**
 * @class
 * GroundtruthRepresentation
 *
 * @brief
 * An instance of a groundtruth token element. Thereby an instance of such a
 * type contains the sentence ID, the token id (which are the token ids of
 * the source elements this groundtruth element are linked to), the correct
 * token, and the exact error type.
 */
class GroundtruthRepresentation {
  /**
   * @brief
   * Constructor. This constructor is used when the source tokens do not
   * represent a span of elements.
   */
  this(ulong aid, ulong nSid, ulong nId1, dstring sCorrect, ErrorTypes nError) {
    this.aid = aid;
    this.sid = nSid;
    this.id1 = nId1;
    this.id2 = nId1;
    this.correct = sCorrect;
    this.error = nError;
  }

  /**
   * @brief
   * Constructor. This constructor is used when the source tokens involve
   ' multiple elements which is usually the case when we have error types like
   * REPEAT or SPLIT.'
   */
  this(ulong aid, ulong nSid, ulong nId1, ulong nId2, dstring sCorrect, ErrorTypes nError) {
    this.aid = aid;
    this.sid = nSid;
    this.id1 = nId1;
    this.id2 = nId2;
    this.correct = sCorrect;
    this.error = nError;
  }

  string asJson() {
    if (this.id1 != this.id2) {
      return format("  {\"affected-id\": \"a%s.s%s.w%s-a%s.s%s.w%s\", \"correct\": \"%s\", \"type\": \"%s\"}",
        this.aid,
        this.sid,
        this.id1,
        this.aid,
        this.sid,
        this.id2,
        to!string(this.correct),
        TypeToName(this.error)
      );
    } else {
      return format("  {\"affected-id\": \"a%s.s%s.w%s\", \"correct\": \"%s\", \"type\": \"%s\"}",
        this.aid,
        this.sid,
        this.id1,
        to!string(this.correct),
        TypeToName(this.error)
      );
    }
  }

  ulong aid; // Article ID
  ulong sid;
  ulong id1;
  ulong id2;
  dstring correct;
  ErrorTypes error;
}

/**
 * @class
 * NeighborRepresentation
 *
 * @brief
 * Helper structure for reading the language dictionary. An instance of this
 * class contains the key (the unique word), its unique id and word type
 * (either REAL_WORD or ARCHAIC) and the ID list of all neighbouring words.
 */
class NeighborRepresentation {
  /**
   * @brief
   * Constructor.
   *
   * @param [in]key
   * The word of this instance.
   * @param [in]id
   * The unique id of this word.
   * @param [in]eType
   * The word type (either REAL_WORD or ARCHAIC).
   * @param [in]neighbours
   * List of all neighbouring IDs (based on some predefined metrics).
   */
  this(dstring key, ulong id, string eType, ulong[] reals, ulong[] archaics, ulong[] errors) {
    this.key = key;
    this.id = id;
    this.eType = eType;
    this.reals = reals;
    this.archaics = archaics;
    this.errors = errors;
  }

  dstring key;
  ulong id;
  string eType;
  ulong[] reals;
  ulong[] archaics;
  ulong[] errors;
}

/**
 * @class
 * SentenceRepresentation
 *
 * @brief
 * Our internal representation of a sentence while we are in the process of
 * parsing and eror generation.
 */
class SentenceRepresentation {
  /**
   * @brief
   * Constructor.
   *
   * @param [in]sSentence
   * The current sentence to observe.
   */
  this(ulong aid, dstring sSentence) {
    this.aid = aid;
    // Just build the internal representation
    this.buildInternalRepresentation(sSentence);
  }


  ulong getNumInitialTokens() {
    return this.numInitialTokens;
  }

  ulong getNumCurrentTokens() {
    return this.tokens.length;
  }


  void setTokenMark(ulong nPosition, MarkTypes nMark) {
    this.marks[nPosition] = nMark;
  }

  void setTokenMarkPosition(ulong nPosition, MarkPosition nMarkPos) {
    this.markPositions[nPosition] = nMarkPos;
  }

  /**
   * @brief
   *
   * @param [in]nPosition
   * @param [in]sToken
   * @param [in]bIsSpace
   * @param [in]nType
   */
  void addTokenAfter(ulong nPosition, dstring sToken, bool bIsSpace, ErrorTypes nType, MarkTypes nMark) {
    this.tokens.insertBefore(this.tokens[nPosition+1..$], sToken);
    this.initials.insertBefore(this.initials[nPosition+1..$], sToken);
    this.spaces.insertBefore(this.spaces[nPosition+1..$], bIsSpace);
    this.errors.insertBefore(this.errors[nPosition+1..$], nType);
    this.marks.insertBefore(this.marks[nPosition+1..$], nMark);
    this.markPositions.insertBefore(this.markPositions[nPosition+1..$], MarkPosition.SOURCE);
  }

  /**
   * @brief
   *
   * @param [in]nPosition
   * @param [in]sToken
   * @param [in]bIsSpace
   * @param [in]nType
   */
  void addTokenBefore(ulong nPosition, dstring sToken, bool bIsSpace, ErrorTypes nType, MarkTypes nMark) {
    this.tokens.insertBefore(this.tokens[nPosition..$], sToken);
    this.initials.insertBefore(this.initials[nPosition..$], sToken);
    this.spaces.insertBefore(this.spaces[nPosition..$], bIsSpace);
    this.errors.insertBefore(this.errors[nPosition..$], nType);
    this.marks.insertBefore(this.marks[nPosition..$], nMark);
    this.markPositions.insertBefore(this.markPositions[nPosition..$], MarkPosition.SOURCE);
  }

  void removeTokenAt(ulong nPosition) {
    this.tokens.linearRemove(this.tokens[nPosition..nPosition]);
    this.initials.linearRemove(this.initials[nPosition..nPosition]);
    this.spaces.linearRemove(this.spaces[nPosition..nPosition]);
    this.errors.linearRemove(this.errors[nPosition..nPosition]);
    this.marks.linearRemove(this.marks[nPosition..nPosition]);
    this.markPositions.linearRemove(this.markPositions[nPosition..nPosition]);
  }


  /**
   * @brief
   * Helper method responsible for building the internal representation of a
   ' sentence, so we can further use that representation in the upcomming
   * generation.
   *
   * @param [in]sSentence
   * The sentence to tokenize.
   * @param [in]nDefaultType
   * The default error type, normally this is NONE.
   */
  private void buildInternalRepresentation(
    dstring sSentence,
    ErrorTypes nDefaultType = ErrorTypes.NONE) {
      // Get all tokens of the sentence
      ulong sSentenceLen = sSentence.length;
      auto tokens = this.tokenizeSentence(sSentence);

      if (sSentence.canFind("Tomatoes")) {
        writeln("tokens: ", tokens[0..$]);
      }

      int nCharPointer = 0;

      this.numInitialTokens = tokens.length;
      // Prevent steady reallocation of arrays
      this.tokens.reserve(this.numInitialTokens);
      this.initials.reserve(this.numInitialTokens);
      this.spaces.reserve(this.numInitialTokens);
      this.errors.reserve(this.numInitialTokens);
      this.marks.reserve(this.numInitialTokens);
      this.markPositions.reserve(this.numInitialTokens);

      // Loop through all tokens and fill up the representation information
      foreach (t; tokens) {
        nCharPointer += t.length; // Increase the length
        bool bSpace = false; // Helper for the detection of whitespaces

        if ((nCharPointer < sSentenceLen) &&
            (isSpace(sSentence[nCharPointer]) || internalIsWhite(sSentence[nCharPointer]))) {
          // Found whitespace at nCharPointer, skip by 1
          bSpace = true;
          while (isSpace(sSentence[nCharPointer]) || internalIsWhite(sSentence[nCharPointer])) {
            nCharPointer += 1;
          }
        }
        this.tokens.insertBack(t); // Insert the tokens to the list of all tokens
        this.initials.insertBack(t);
        this.spaces.insertBack(bSpace); // Insert information about whether next pos in sentence is a whitespace
        this.errors.insertBack(nDefaultType); // Insert default error tyoe
        this.marks.insertBack(MarkTypes.NONE); // Insert the default mark NONE
        this.markPositions.insertBack(MarkPosition.SOURCE);
      }
  }

  private bool internalIsWhite(dchar cChar) {
    return (isWhite(cChar) || (cChar == '\uFFFD') || (cChar == '\uFFFC') || (cChar == '\u00A0'));
  }

  Array!dstring tokenizeSentence(dstring sSentence) {
    Array!dstring result;
    //auto r = regex(r"\w+\-\w+|\w+|[^\w\s]");
    foreach (c; matchAll(to!string(sSentence), rTokenize)) {
      result.insertBack(to!dstring(c[0]));
    }
    //if ( in result) {
    //  writeln(result[0..$]);
    //}
    return result;
  }

  ulong aid; // Article ID
  Array!dstring tokens;
  Array!dstring initials;
  Array!bool spaces;
  Array!ErrorTypes errors;
  Array!MarkTypes marks;
  Array!MarkPosition markPositions;

  ulong numInitialTokens;

  static auto rTokenize = ctRegex!r"(?:\d+[,.]\d+)|(?:[\w'\u0080-\u9999]+(?:[-]+[\w'\u0080-\u9999]+)+)|(?:[\w\u0080-\u9999]+(?:[']+[\w\u0080-\u9999]+)+)|\b[_]|(?:[_]*[\w\u0080-\u9999]+(?=_\b))|(?:[\w\u00A1-\u9999]+)|[^\w\s\u00A0\p{Z}]"; // NOLINT
  //static auto rTokenize = ctRegex!r"\w+\-\w+|\w+'\w+|\w+|[^\w\s]";
}
