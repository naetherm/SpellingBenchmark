// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.helper;

import devaluator.utils.tokenizer: Tokenizer;
import devaluator.utils.types;
import std.container;
import std.conv;
import std.json;
import std.regex;
import std.stdio;
import std.string;
import std.container.rbtree;

alias Set = redBlackTree;

alias Table = int[][][];
//alias Table = redBlackTree!(int)[][][];
// -> https://dlang.org/phobos/std_container_rbtree.html



/** 
 * @class
 * TArticle
 *
 * Basic implementation of a article description, this class can be used by any *Repr.
 */
class TArticle(TSentence) {
  /** 
   * Constructor.
   */
  this() {}

  ref TSentence opIndex(size_t nIdx) { return this.sentences[nIdx]; }

  /** 
   * Returns the number of sentences within an article.
   * Returns: Number of sentences within article
   */
  ulong numSentences() const { return this.sentences.length; }

  /** 
   * Adds an additional sentence representation to the article.
   * Params:
   *   sentence = The sentence to add to the article description.
   */
  void add(TSentence sentence) { this.sentences[this.sentences.length] = sentence; }

  /** 
   * Returns a reference to the sentence at index position nIdx.
   * Params:
   *   nIdx = The index position of the sentence to return.
   * Returns: Reference to the sentence at position nIdx.
   */
  ref TSentence get(ulong nIdx) { return this.sentences[nIdx]; }

  /** 
   * Returns a reference to the last sentence within this article.
   * Returns: Reference to last sentence.
   */
  ref TSentence last() { return this.sentences[this.sentences.length-1]; }

  /** 
   * Array containing all sentences of this article.
   */
  TSentence[ulong] sentences;
}


class JoinedGap {

  this() {

  }

  this(long[] first, long[] second) {
    this.first = first;
    this.second = second;
  }

  long[] first;
  long[] second;
}


/**
 * @class AbstractRepr
 *
 * @brief
 */
class AbstractRepr {
  /**
   * @brief
   * Constructor.
   */
  this() {

  }

  /**
   * @brief
   */
  bool isRange(dstring id) {
    return (id.indexOf('-') != -1);
  }

  /** 
   * Gets 
   * Params:
   *   ids = The string containing the format "aX.sY.wZ" or "aX1.sY1.wZ1-aX2.sY2.wZ2"
   * Returns: List of all found numbers (normally 3 or 6)
   */
  ulong[] getRange(dstring ids) {
    auto r = regex(r"\d+");
    ulong[] result;
    foreach(m; matchAll(to!string(ids), r)) {
      result ~= to!ulong(m[0]);
    }

    return result;
  }

  dstring asString(ulong aidx, ulong sidx) {
    return "";
  }
}

////////////////////////////////////////////////////////////////////////////////
// Prediction Representation
////////////////////////////////////////////////////////////////////////////////

class PredictionToken {
  /**
   * @brief
   * Default constructor.
   */
  this() {
    this.type = "";
  }

  /**
   * @brief
   * Constructor.
   *
   * @param [in]id
   * @param [in]token
   * @param [in]suggestions
   * @param [in]space
   */
  this(ulong id, dstring token, dstring[] suggestions, bool space) {
    this.id = id;
    this.token = token;
    foreach (t; suggestions) {
      this.suggestions ~= t;
    }
    this.space = space;
  }

  void addSuggestion(dstring suggestion) {
    this.suggestions ~= suggestion;
  }

  ulong id;

  dstring token;

  /**
   * The predicted type, this is only set if the tool dies support it.
   */
  dstring type;

  dstring[] suggestions;

  bool space;
}

class PredictionSentence {
  /**
   * @brief
   * Default constructor.
   */
  this() {

  }

  ref PredictionToken opIndex(ulong tidx) {
    return this.tokens[tidx];
  }

  void toString(scope void delegate(const(char)[]) sink) const {
    sink("PredictionRepr ");
    for (int t = 0; t < this.tokens.length; t++) {
      sink("\tid: "); sink(to!string(this.tokens[t].id)); sink(" ");
      sink("\ttoken: "); sink(to!string(this.tokens[t].token)); sink(" ");
      sink("\tsuggestions: "); sink(to!string(this.tokens[t].suggestions)); sink("\n");
    }
  }

  /**
   * @brief
   * Adds an additional token to the list of tokens for this sentence.
   *
   * @param [in]token
   * The token to add.
   */
  void addToken(PredictionToken token) {
    this.tokens[this.tokens.length] = token;
  }

  /**
   * @brief
   * Returns a reference to the last token of this sentence.
   *
   * @return
   * Reference to last token.
   */
  ref PredictionToken last() {
    return this.tokens[this.tokens.length-1];
  }

  dstring asString() {
    dstring result = "";

    for (int i = 0; i < this.tokens.length; i++) {
      result ~= this.tokens[i].token;
      if (this.tokens[i].space) {
        result ~= " ";
      }
    }

    return result;
  }

  ulong getNumTokens() {
    return this.tokens.length;
  }

  /**
   * List of all tokens of the current prediction. Keep in mind that all tokens
   * must be in the correct order of the sentence itself!
   */
  PredictionToken[ulong] tokens;
}

/**
 * @class
 * PredictionRepr
 *
 * @brief
 * Wrapper around the prediction representation of a given program. The prediction
 * representation contains the information of the id, and thereby the position
 * within the prediction, the token that was assigned to that position and, if
 * available by the program, other suggestions if there are multiple possible
 * solutions given.
 */
class PredictionRepr : AbstractRepr {
  /**
   * @brief
   * Constructor. This constructor receives the prediction data string.
   *
   * @param [in]input
   * The prediction data string.
   */
  this() {

  }

  /** 
   * Returns the number of articles.
   * Returns: The number of articles.
   */
  ulong numArticles() {
    return this.articles.length;
  }

  void initialize(ulong aidx, ulong numSentences) {
    this.articles[aidx] = new TArticle!(PredictionSentence);
    foreach (i; 0..numSentences) {
      this.articles[aidx].add(new PredictionSentence());
    }
  }

  ref TArticle!(PredictionSentence) opIndex(size_t idx) {
    return this.articles[idx];
  }

  override dstring asString(ulong aidx, ulong sidx) {
    return this.articles[aidx].sentences[sidx].asString();
  }

  ref PredictionToken getToken(ulong aidx, ulong sidx, ulong tidx) {
    return this.articles[aidx].sentences[sidx].tokens[tidx];
  }

  dstring[] getTokens(ulong aidx, ulong idx) {
    auto sentence = this.articles[aidx].sentences[idx];

    dstring[] result;

    foreach (i; 0..sentence.tokens.length) {
      result ~= sentence.tokens[i].token;
    }

    return result;
  }

  ulong getNumTokens(ulong aidx, ulong sidx) {
    return this.articles[aidx].sentences[sidx].tokens.length;
  }

  /**
   * The raw source sentence.
   */
  dstring raw;

  /**
   * parsed json for the source sentences.
   */
  JSONValue repr;

  /**
   * Dynamic array containing all sentences ofthe prediction.
   */
  TArticle!(PredictionSentence)[ulong] articles;
}

////////////////////////////////////////////////////////////////////////////////
// Raw Representation
////////////////////////////////////////////////////////////////////////////////

/**
 * @class
 * RawRepr
 *
 * @brief
 * Wrapper around the raw representation of benchmark data. The raw representation
 * contains to original data without any spelling errors.
 */
class RawRepr : AbstractRepr {
  /**
   * @brief
   * Constructor. This constructor receives the raw data string.
   *
   * @param [in]input
   * The raw data string.
   */
  this(const ref dstring input) {
    this.raw = input;

    this.build();
  }

  /**
   * @brief
   * Build.
   */
  void build() {
    // Split input lines into sentences
    auto source_sentences = this.raw.split("\n");

    foreach (l; source_sentences) {
      if (l.length > 0) {
        dstring[] tokens;
        foreach (c; matchAll(to!string(l), Tokenizer)) {
          tokens ~= to!dstring(c[0]);
        }
        this.all_tokens.insertBack(tokens);
      }
    }
  }

  override dstring asString(ulong aidx, ulong sidx) {
    return "";
  }

  /**
   * The raw source sentence.
   */
  dstring raw;
  /**
   * Dynamic array containing all tokens of the source input.
   */
  Array!(dstring[]) all_tokens;
}

////////////////////////////////////////////////////////////////////////////////
// Source Representation
////////////////////////////////////////////////////////////////////////////////

class SourceToken {
  /**
   * @brief
   * Default constructor. Used for initialization of associative arrays.
   */
  this() {

  }

  /**
   * @brief
   * Constructor.
   *
   * qparam [in]id
   * The unique id of the current source token.
   * @param [in]token
   * the token itself.
   * @param [in]space
   * Determines whether a space should occur after the token.
   */
  this(ulong id, dstring token, bool space) {
    this.id = id;
    this.token = token;
    this.space = space;
  }

  /**
   * The unique ID of the token.
   */
  ulong id;
  /**
   * The token itself.
   */
  dstring token;
  /**
   * Determines whether there should be a space behind this token.
   */
  bool space;
}

/**
 * @class
 * SourceSentence
 *
 * @brief
 * A simple representation of a sentence of the source input.
 */
class SourceSentence {
  /**
   * @brief
   * Default constructor.
   */
  this() {

  }


  ref SourceToken opIndex(ulong tidx) {
    return this.tokens[tidx];
  }

  /**
   * @brief
   * Adds an additional token to the list of source tokens.
   *
   * @param [in]token
   * The token that should be added.
   */
  void addToken(SourceToken token) {
    this.tokens[this.tokens.length] = token;
  }

  /**
   * @brief
   * Returns the last token.
   */
  ref SourceToken last() {
    return this.tokens[this.tokens.length-1];
  }

  dstring asString() {
    dstring result = "";

    foreach (i; 0..this.tokens.length) {
      result ~= this.tokens[i].token;

      if (this.tokens[i].space) {
        result ~= " ";
      }
    }

    return result;
  }

  ulong getNumTokens() {
    return this.tokens.length;
  }

  /**
   * List of all tokens for the current source sentence.
   */
  SourceToken[ulong] tokens;
}

/**
 * @class
 * SourceRepr
 *
 * @brief
 * The raw source representation.
 */
class SourceRepr : AbstractRepr {
  /**
   * @brief
   * Constructor. Receives the raw source input sentence as raw string.
   *
   * @param [in]input
   * The raw source as string.
   */
  this() {

  }

  /** 
   * Returns the number of articles.
   * Returns: The number of articles.
   */
  ulong numArticles() {
    return this.articles.length;
  }

  ref TArticle!(SourceSentence) opIndex(size_t idx) {
    return this.articles[idx];
  }

  void initialize(ulong aidx, ulong numSentences) {
    this.articles[aidx] = new TArticle!(SourceSentence);
    foreach (i; 0..numSentences) {
      this.articles[aidx].add(new SourceSentence());
    }
  }

  ref SourceToken getToken(ulong aidx, ulong sidx, ulong tidx) {
    return this.articles[aidx].sentences[sidx].tokens[tidx];
  }

  override dstring asString(ulong aidx, ulong sidx) {
    return this.articles[aidx].sentences[sidx].asString();
  }

  dstring[] getTokens(ulong aidx, ulong idx) {
    auto sentence = this.articles[aidx].sentences[idx];

    dstring[] result;

    foreach (i; 0..sentence.tokens.length) {
      result ~= sentence.tokens[i].token.dup;
    }

    return result;
  }

  ulong getNumTokens(ulong aidx, ulong sidx) {
    return this.articles[aidx].sentences[sidx].tokens.length;
  }

  /**
   * The raw source sentence.
   */
  dstring raw;

  /**
   * Parsed json for the source sentences.
   */
  JSONValue repr;

  /**
   * Dynamic array of all sentences of the source input.
   */
  TArticle!(SourceSentence)[ulong] articles;

}

////////////////////////////////////////////////////////////////////////////////
// Groundtruth Representation
////////////////////////////////////////////////////////////////////////////////

class GroundtruthToken {
  /**
   * @brief
   * Default constructor.
   */
  this() {

  }

  this(ulong id, dstring token) {
    this.id = id;
    this.source_ids ~= id;
    this.source_token = token;
    this.target_token = token;
    this.error_type = ErrorTypes.NONE;
  }

  this(ulong id, ulong[] sourceIDs, dstring sourceToken, dstring targetToken, ErrorTypes errorType) {
    this.id = id;
    this.source_ids = sourceIDs;
    this.source_token = sourceToken;
    this.target_token = targetToken;
    this.error_type = errorType;
  }

  ulong id;
  ulong[] source_ids;
  dstring source_token;
  dstring target_token;
  ErrorTypes error_type;

}

class GroundtruthSentence {

  this() {

  }

  ref GroundtruthToken opIndex(ulong tidx) {
    return this.tokens[tidx];
  }

  void addToken(GroundtruthToken token) {
    this.tokens[this.tokens.length] = token;
  }

  ref GroundtruthToken token(ulong idx) {
    return this.tokens[idx];
  }

  ref GroundtruthToken last() {
    return this.tokens[this.tokens.length-1];
  }

  GroundtruthToken[ulong] tokens;
}

/**
 * @class
 * GroundtruthRepr
 *
 * @brief
 * The raw groundtruth representation.
 */
class GroundtruthRepr : AbstractRepr {
  /**
   * @brief
   * Constructor. Receives the raw groundtruth information as string wrapped json
   * representation.
   *
   * @param [in]input
   *
   */
  this() {
    
  }

  /** 
   * Returns the number of articles.
   * Returns: The number of articles.
   */
  ulong numArticles() {
    return this.articles.length;
  }


  ref TArticle!(GroundtruthSentence) opIndex(ulong sidx) {
    return this.articles[sidx];
  }

  void initialize(ulong aidx, ulong numSentences) {
    this.articles[aidx] = new TArticle!(GroundtruthSentence);
    foreach (i; 0..numSentences) {
      this.articles[aidx].add(new GroundtruthSentence());
    }
  }

  override dstring asString(ulong aidx, ulong sidx) {
    return "";
  }

  dstring[] getSourceTokens(ulong aidx, ulong idx) {
    auto sentence = this.articles[aidx].sentences[idx];

    dstring[] result;

    foreach (i; 0..sentence.tokens.length) {
      result ~= sentence.tokens[i].source_token;
    }

    return result;
  }

  dstring[] getTokens(ulong aidx, ulong idx) {
    auto sentence = this.articles[aidx].sentences[idx];

    dstring[] result;

    foreach (i; 0..sentence.tokens.length) {
      result ~= sentence.tokens[i].target_token;
    }

    return result;
  }

  ulong getNumTokensForSentence(ulong aidx, ulong sidx) {
    return this.articles[aidx].sentences[sidx].tokens.length;
  }

  ulong numSentences(ulong aidx) {
    return this.articles[aidx].numSentences();
  }

  ref GroundtruthToken getToken(ulong aidx, ulong sidx, ulong tidx) {
    return this.articles[aidx].sentences[sidx].tokens[tidx];
  }

  /**
   * The raw groundtruth input.
   */
  dstring groundtruth;

  /**
   * the raw source input.
   */
  //dstring source;
  SourceRepr source;

  /**
   * Parsed json of the input groundturth.
   */
  JSONValue repr;

  /**
   * List of all sentences.
   */
  TArticle!(GroundtruthSentence)[ulong] articles;
}
