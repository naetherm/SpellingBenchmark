// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.utils.data_reader;

import devaluator.utils.types;
import devaluator.utils.helper;

import std.container;
import std.conv;
import std.string;
import std.stdio;
import std.typecons: tuple, Tuple;

alias Result = Tuple!(SourceRepr, GroundtruthRepr, PredictionRepr);

/**
 * @interface
 * DataReaderInterface
 *
 * @brief
 * Data reader interface.
 */
interface DataReaderInterface {

  SourceRepr parseSource(dstring input);

  PredictionRepr parsePrediction(dstring input);

  GroundtruthRepr parseGroundtruth(dstring input);
}

/**
 * @class
 * DataReaderWrapper
 *
 * Wrapper for all specific dataset readers.
 */
class DataReaderWrapper : DataReaderInterface {

  /**
   * Sets the internal information about the number of articles and sentences per article.
   * This information is read from groundtruth["information"] -> "numArticles" and "sentences".
   * Params:
   *   input = The groundtruth information
   */
  void setUp(ref dstring input) {
    import std.json;

    auto parsed = parseJSON(input);

    this.numArticles = to!ulong(parsed["information"]["numArticles"].integer);

    this.sentencesPerArticle.destroy();

    auto temp = parsed["information"]["sentences"].arrayNoRef;

    foreach (s; temp) {
      this.sentencesPerArticle ~= to!ulong(s.integer);
    }

    writeln("numArticles: ", this.numArticles);
    writeln("sentences: ", this.sentencesPerArticle);
  }

  SourceRepr parseSource(dstring input) {
    return null;
  }

  PredictionRepr parsePrediction(dstring input) {
    return null;
  }

  GroundtruthRepr parseGroundtruth(dstring input) {
    return null;
  }

  ulong numArticles;
  ulong[] sentencesPerArticle;
  SourceRepr sRepr;
  PredictionRepr pRepr;
  GroundtruthRepr gRepr;
}

class JSONDataReader : DataReaderWrapper {

  this() {}

  override SourceRepr parseSource(dstring input) {
    import std.json;

    this.sRepr = new SourceRepr();

    // Initialize the article and sentence information
    foreach (a; 0..this.numArticles) {
      this.sRepr.initialize(a, this.sentencesPerArticle[a]);
    }

    auto parsed = parseJSON(input);

    foreach (ulong tidx, t; parsed["tokens"]) {
      auto parsed_ids = this.sRepr.getRange(to!dstring(t["id"].str));

      this.sRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].addToken(
        new SourceToken(
          parsed_ids[2],
          to!dstring(t["token"].str),
          t["space"].boolean
        )
      );
    }

    return this.sRepr;
  }

  override PredictionRepr parsePrediction(dstring input) {
    import std.json;

    this.pRepr = new PredictionRepr();

    // Initialize the article and sentence information
    foreach(a; 0..this.numArticles) {
      this.pRepr.initialize(a, this.sentencesPerArticle[a]);
    }

    auto parsed = parseJSON(input);

    foreach (ulong tidx, t; parsed["predictions"]) {
      // The parsed_ids has the following layout: "aX.sY.wZ"
      auto parsed_ids = this.pRepr.getRange(to!dstring(t["id"].str));

      // Receive and convert all suggestions from string to dstring
      auto suggestions = t["suggestions"].arrayNoRef;
      dstring[] dsugg;
      foreach (s; suggestions) {
        dsugg ~= to!dstring(s.str);
      }

      // Create new token
      this.pRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].addToken(
        new PredictionToken(
          parsed_ids[2],
          to!dstring(t["token"].str),
          dsugg.dup,
          t["space"].boolean
          )
      );

      // Check if the tool proposes a type
      if ("type" in t) {
        this.pRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].last().type = to!dstring(t["type"].str);
      }
    }

    return this.pRepr;
  }

  override GroundtruthRepr parseGroundtruth(dstring input) {
    import std.json;

    this.gRepr = new GroundtruthRepr();

    // Initialize the article and sentence information
    foreach (a; 0..this.numArticles) {
      this.gRepr.initialize(a, this.sentencesPerArticle[a]);
    }

    auto parsed = parseJSON(input);

    long shift = 0;
    ulong prev_sidx = 0;
    ulong prev_aidx = 0;

    foreach(ulong gidx, g; parsed["corrections"]) {
      // The object parsed_ids has one of the following layouts:
      // "aX.sY.wZ" or "aX1.sY1.wZ1-a.X2.sY2.wZ2"
      // The first two IDs nether the less are always correct
      auto parsed_ids = this.gRepr.getRange(to!dstring(g["affected-id"].str));

      this.gRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].addToken(
        new GroundtruthToken()
      );

      if (prev_aidx != parsed_ids[0]) {
        // TODO(naetherm): Implement this! Is there anything to do at all?
        prev_aidx = parsed_ids[0];
      }

      if (prev_sidx != parsed_ids[1]) {
        shift = 0;
        prev_sidx = parsed_ids[1];
      }
 // TODO: Shift
      ulong[] sids_;

      // Fetch the sentence IDs
      for (int i = 2; i < parsed_ids.length; i+=3) {
        sids_ ~= parsed_ids[i];
      }

      this.gRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].last().id = parsed_ids[2] - shift;
      this.gRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].last().source_ids = sids_;
      if (sids_.length == 1) {
        this.gRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].last().source_token = this.sRepr.getToken(parsed_ids[0], parsed_ids[1], sids_[0]).token.dup;
      } else {
        this.gRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].last().source_token = this.sRepr.getToken(parsed_ids[0], parsed_ids[1], sids_[0]).token.dup;
        this.gRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].last().source_token ~= to!dstring(" ");
        this.gRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].last().source_token ~= this.sRepr.getToken(parsed_ids[0], parsed_ids[1], sids_[1]).token.dup;
      }
      this.gRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].last().target_token = to!dstring(g["correct"].str);
      this.gRepr.articles[parsed_ids[0]].sentences[parsed_ids[1]].last().error_type = NameToType(g["type"].str);


      if (this.gRepr.isRange(to!dstring(g["affected-id"].str))) {
        ++shift;
      }
    }

    return this.gRepr;
  }
}

class XMLDataReader : DataReaderWrapper {

  this() {

  }

  override SourceRepr parseSource(dstring input) {
    return null;
  }

  override PredictionRepr parsePrediction(dstring input) {
    return null;
  }

  override GroundtruthRepr parseGroundtruth(dstring input) {
    return null;
  }
}

class MarkdownDataReader : DataReaderWrapper {

  this() {

  }

  override SourceRepr parseSource(dstring input) {
    return null;
  }

  override PredictionRepr parsePrediction(dstring input) {
    return null;
  }

  override GroundtruthRepr parseGroundtruth(dstring input) {
    return null;
  }
}



class DataReader {

  this() {
    this.setUp();
  }

  void setUp() {
    this.dataReaders["json"] = new JSONDataReader();
  }

  Result parse(ref dstring source, ref dstring groundtruth, ref dstring prediction) {
    string reader = "invalid";
    if (this.isJson(prediction)) {
      reader = "json";
    }

    this.dataReaders[reader].setUp(groundtruth);

    return tuple(
      this.dataReaders[reader].parseSource(source),
      this.dataReaders[reader].parseGroundtruth(groundtruth),
      this.dataReaders[reader].parsePrediction(prediction)
    );
  }

  private {
    bool isJson(ref dstring input) {
      return input.startsWith("{");
    }

    bool isXml(ref dstring input) {
      import std.xml;

      try {
        check(to!string(input));
      } catch (CheckException e) {
        return false;
      }
      return true;
    }
  }

  private {
    DataReaderWrapper[string] dataReaders;

  }
}
