// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module dgenerator.dataset.wikipedia;

import dgenerator.dataset.datasource: DataSource;

import snck: snck;

import dgenerator.utils.config;
import dgenerator.utils.helper;
import dgenerator.noise.noiser;
import dgenerator.utils.types;

import std.container: Array;
import std.array: assocArray;
import std.file;
import std.path;
import std.json;
import std.range;
import std.regex;
import std.stdio;
import std.string;
import std.typecons;
import std.variant;
import std.conv;

class Wikipedia : DataSource {

  this(Variant[string] cArgs) {
    // The arguments
    this.mcArgs = cArgs;

    // Parameters for the noiser
    Variant[string] noiser_params = [
      "lang_code": this.mcArgs["lang_code"],
      "data_dir": this.mcArgs["data_dir"],
      "seed": this.mcArgs["seed"],
      "num_tries": Variant(5),
      "debug": Variant(false),
      "allow_further_destroy": Variant(false),
      "selfcheck": this.mcArgs["selfcheck"]
    ];

    // Generate links
    this.mFilenames = this.generateLinkFilenames(buildPath(this.mcArgs["input_dir"].get!string, "links.txt"));

    // Initialize and read the configuration file, through which all generators are initialized
    this.config = new Config(this.mcArgs["config"].get!string);

    // Initialize the noiser
    this.mNoiser = new Noiser(noiser_params, this.config);

    this.mModFlag = 1;

    this.bTrainingSet = this.mcArgs["trainingset"].get!bool;
  }

  /**
   *
   */
  void generate() {
    if (this.mcArgs["mode"].get!string == "full_benchmark") {
      this.mModFlag = 1;
    } else if (this.mcArgs["mode"].get!string == "large_benchmark") {
      this.mModFlag = 1000;
    } else if (this.mcArgs["mode"].get!string == "medium_benchmark") {
      this.mModFlag = 10_000;
    } else if (this.mcArgs["mode"].get!string == "tiny_benchmark") {
      this.mModFlag = 100_000;
    } else if (this.mcArgs["mode"].get!string == "smallish_benchmark") {
      this.mModFlag = 600_000;
    } else {
      writeln("WARNING: Unknown benchmark mode, will use 'full_benchmark' as default one!");
    }

    if (exists(buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "source.tar.gz"))) {
      writeln(">> Benchmark files already exist, will skip this benchmark generation.");
    } else {
      write("Starting creation of benchmark files ...");
      this.generate_new();
      writeln("\t Done.");
    }
  }

  void generate_new() {
    static auto rTokenize = ctRegex!r"(?:\d+[.,]\d+)|(?:[\w'\u0080-\u9999]+(?:[-]+[\w'\u0080-\u9999]+)+)|(?:[\w\u0080-\u9999]+(?:[']+[\w\u0080-\u9999]+)+)|\b[_]|(?:[_]*[\w\u0080-\u9999]+(?=_\b))|(?:[\w\u00A1-\u9999]+)|[^\w\s\u00A0\p{Z}]";

    write("Write new links.txt file ...");
    if (!exists(buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "raw"))) {
      mkdirRecurse(buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "raw"));
    }
    if (!exists(buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "source"))) {
      mkdirRecurse(buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "source"));
    }
    if (!exists(buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "groundtruth"))) {
      mkdirRecurse(buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "groundtruth"));
    }
    auto linksFile = File(buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "links.txt"), "w");
    auto grtLinksFile = File(buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "groundtruth", "links.txt"), "w");
    int counter = 0;
    foreach (l; this.mFilenames) {
      if ((counter % this.mModFlag) == 0) {
        auto pcs = l.split("/");
        linksFile.writeln(this.mcArgs["dataset"].get!string ~ "/" ~ pcs[$-2] ~ "/" ~ pcs[$-1]);
        grtLinksFile.writeln(this.mcArgs["dataset"].get!string ~ "/" ~ pcs[$-2] ~ "/" ~ pcs[$-1]);
      }
      counter += 1;
    }
    linksFile.close();
    grtLinksFile.close();
    writeln("\tdone.");

    string globalRawFilename = buildPath(this.mcArgs["output_dir"].get!string) ~ this.mcArgs["mode"].get!string ~ "_raw.txt";
    string globalSrcFilename = buildPath(this.mcArgs["output_dir"].get!string) ~ this.mcArgs["mode"].get!string ~ "_source" ~ "." ~ this.mcArgs["format"].get!string;
    string globalGrtFilename = buildPath(this.mcArgs["output_dir"].get!string) ~ this.mcArgs["mode"].get!string ~ "_groundtruth" ~ "." ~ this.mcArgs["format"].get!string;
    writeln("globalRawFilename: ", globalRawFilename);
    writeln("globalSrcFilename: ", globalSrcFilename);
    writeln("globalGrtFilename: ", globalGrtFilename);
    int globalSentenceID = 0;

    string sRawOutput;
    string sSourceOutput;
    string sGroundtruthOutput;

    if (this.mcArgs["format"] == "json") {
      sSourceOutput = "{ \"tokens\": [\n";
      sGroundtruthOutput = "{ \"corrections\": [\n";
    } else if (this.mcArgs["format"] == "xml") {
      sSourceOutput = "<tokens>\n";
      sGroundtruthOutput = "<corrections>\n";
    }

    ulong[] sentencesPerArticle;
    ulong nArticleCounter = 0;
    foreach (i; iota(this.mFilenames.length).snck) {
      if (((i+1) % this.mModFlag) == 0) {
        auto l = this.mFilenames[i];
        //writeln("Read from file: ", l);
        dstring readBuf = to!dstring(readText(l));
        auto content = readBuf.lineSplitter().array;

        // Some small cleanup of the remaining data
        foreach (j; 0..content.length) {
          while (indexOf(content[j], "[]", 0) !is -1)
            content[j] = content[j].replace("[]", "");
          while (indexOf(content[j], "()", 0) !is -1)
            content[j] = content[j].replace("()", "");
          while (indexOf(content[j], "(;)", 0) !is -1)
            content[j] = content[j].replace("(;)", "");
          while (indexOf(content[j], "(; )", 0) !is -1)
            content[j] = content[j].replace("(; )", "");
          while (indexOf(content[j], "(,)", 0) !is -1)
            content[j] = content[j].replace("(,)", "");
          while (indexOf(content[j], "(, )", 0) !is -1)
            content[j] = content[j].replace("(, )", "");
          while (indexOf(content[j], "  ", 0) !is -1)
            content[j] = content[j].replace("  ", " ");
        }

        Array!string srcPcs = l.split("/");
        // Generate noise here
        Tuple!(dstring, SentenceRepresentation)[] pairs;

        foreach(s; content) {
          pairs ~= tuple(s, this.mNoiser.generateNoise(nArticleCounter, s));
        }
        sentencesPerArticle ~= content.length; // Add the number of sentences to the sentencesPerArticle array
        SourceRepresentation[] srcTokens;
        GroundtruthRepresentation[] grtTokens;
        //int gIdx = 0;
        foreach(sIdx, e; pairs.enumerate(0)) {
          dstring s = e[0]; // This is the raw sentence
          sRawOutput ~= to!string(e[0]) ~ "\n";
          SentenceRepresentation n = e[1]; // The sentence representation, created by the noiser

          // Write the input information
          ulong srcPosition = 0;
          for (size_t tIdx = 0; tIdx < n.getNumCurrentTokens(); tIdx++) {
            srcTokens ~= new SourceRepresentation(nArticleCounter, sIdx, tIdx, srcPosition, n.tokens[tIdx], n.spaces[tIdx]);
            srcPosition += n.tokens[tIdx].length;
            if (n.spaces[tIdx]) {
              srcPosition += 1;
            }
          }

          // Create the groundtruth information
          Array!string inpTokens;
          foreach (t; matchAll(to!string(s), rTokenize)) { inpTokens.insertBack(t); }
          // We are using two variables here for the later introduction of categories like SPLIT, CONCATENATION and REPEAT

          ulong tIdx = 0;
          ulong ii = 0;
          ulong grtPosition = 0;
          while (ii < n.getNumCurrentTokens()) {
            ulong shift = 0;
            //TODO[FGRT]if (n.errors[ii] != ErrorTypes.NONE) {
            // Check whether this is a 'complex' type like SPLIT or REPEAT
            if ((n.marks[ii] == MarkTypes.START) && (n.markPositions[ii] != MarkPosition.GROUNDTRUTH))  {
              // Find the END Mark
              while (n.marks[ii++] != MarkTypes.END) { shift++; }
              --ii;
            }
            if (n.marks[ii] == MarkTypes.SOURCE_ONLY) {
              shift++;
              // Generate the groundtruth information
              grtTokens ~= new GroundtruthRepresentation(
                nArticleCounter,
                sIdx,
                ii,
                ii,
                grtPosition,
                to!dstring(""),
                n.errors[ii]);
            } else {
              // Generate the groundtruth information
              grtTokens ~= new GroundtruthRepresentation(
                nArticleCounter,
                sIdx,
                ii-shift,
                ii,
                grtPosition,
                to!dstring(inpTokens[tIdx]),
                n.errors[ii]);
              tIdx++;
            }
            //TODO[FGRT]}
            // Increase all counters
            if (n.marks[ii] == MarkTypes.SOURCE_ONLY) {
              if (n.spaces[ii]) {
                grtPosition += 1;
              }
            } else {
              grtPosition += inpTokens[tIdx].length;
              for (int spaces = 0; spaces < shift; ++i) {
                grtPosition += n.spaces[spaces+ii] ? 1 : 0;
              }
            }
            ii++;
          }
          globalSentenceID += 1;
        }


        // Write source and groundtruth information to files
        if (this.mcArgs["format"] == "json") {
          foreach (idx, t; srcTokens.enumerate(0)) {
            // Some post corrections on the token data
            if (t.token == "\"") {
              t.token = t.token.replace("\"", "\\\"");
            }
            if (t.token == "\\") {
              t.token = t.token.replace("\\", "\\\\");
            }
            if ((idx == (srcTokens.length - 1)) && (i == (this.mFilenames.length - 1))) {
              sSourceOutput ~= format("  {\"id\": \"a%s.s%s.w%s\", \"token\": \"%s\", \"pos\": %d, \"length\": %d, \"space\": %s}\n", t.aid, t.sid, t.id, to!string(t.token), t.pos, t.token.length, t.space);
            } else {
              sSourceOutput ~= format("  {\"id\": \"a%s.s%s.w%s\", \"token\": \"%s\", \"pos\": %d, \"length\": %d, \"space\": %s},\n", t.aid, t.sid, t.id, to!string(t.token), t.pos, t.token.length, t.space);
            }
          }

          foreach (idx, t; grtTokens.enumerate(0)) {
            // Some post corrections on the token data
            if (t.correct == "\"") {
              t.correct = t.correct.replace("\"", "\\\"");
            }
            if (t.correct == "\\") {
              t.correct = t.correct.replace("\\", "\\\\");
            }
            if (t.id1 != t.id2) {
              sGroundtruthOutput ~= format("  {\"affected-id\": \"a%s.s%s.w%s-a%s.s%s.w%s\", \"correct\": \"%s\", \"pos\": %d, \"length\": %d, \"type\": \"%s\"}", t.aid, t.sid, t.id1, t.aid, t.sid, t.id2, to!string(t.correct), t.pos, t.correct.length, TypeToName(t.error));
            } else {
              sGroundtruthOutput ~= format("  {\"affected-id\": \"a%s.s%s.w%s\", \"correct\": \"%s\", \"pos\": %d, \"length\": %d, \"type\": \"%s\"}", t.aid, t.sid, t.id1, to!string(t.correct), t.pos, t.correct.length, TypeToName(t.error));
            }
            if ((idx == (grtTokens.length - 1)) && (i == (this.mFilenames.length - 1))) {
              sGroundtruthOutput ~= "\n";
            } else {
              sGroundtruthOutput ~= ",\n";
            }
          }
        } else if (this.mcArgs["format"] == "xml") {
          foreach (idx, t; srcTokens.enumerate(0)) {
            // Some post corrections on the token data
            if (t.token == "\"") {
              t.token = t.token.replace("\"", "\\\"");
            }
            if (t.token == "\\") {
              t.token = t.token.replace("\\", "\\\\");
            }
            sSourceOutput ~= format("  <st id=\"a%s.s%s.w%s\" token=\"%s\" pos=\"%d\" length=\"%d\" space=\"%s\"/>\n", t.aid, t.sid, t.id, to!string(t.token), t.pos, t.token.length, t.space);
          }
          foreach (idx, t; grtTokens.enumerate(0)) {
            // Some post corrections on the token data
            if (t.correct == "\"") {
              t.correct = t.correct.replace("\"", "\\\"");
            }
            if (t.correct == "\\") {
              t.correct = t.correct.replace("\\", "\\\\");
            }
            if (t.id1 != t.id2) {
              sGroundtruthOutput ~= format("  <correction affected-id=\"a%s.s%s.w%s-a%s.s%s.w%s\" correct=\"%s\" pos=\"%d\" length=\"%d\" type=\"%s\"/>\n", t.aid, t.sid, t.id1, t.aid, t.sid, t.id2, to!string(t.correct), t.pos, t.correct.length, TypeToName(t.error));
            } else {
              sGroundtruthOutput ~= format("  <correction affected-id=\"a%s.s%s.w%s\" correct=\"%s\" pos=\"%d\" length=\"%d\" type=\"%s\"/>\n", t.aid, t.sid, t.id1, to!string(t.correct), t.pos, t.correct.length, TypeToName(t.error));
            }
          }
        }

        // Increment the article counter
        ++nArticleCounter;
      }

    }
    // Some information for us
    writeln("Created information for ", nArticleCounter, " articles.");

    writeln("add some internal information");

    // Add closing brackets to source and groundtruth output and write to file
    if (this.mcArgs["format"] == "json") {
      sSourceOutput = sSourceOutput[0..$-2] ~ "\n ],\n" ~
        " \"information\": { \"numArticles\": " ~ to!string(sentencesPerArticle.length) ~
        ", \"sentences\": "~ to!string(sentencesPerArticle) ~
        " }\n}";
      sGroundtruthOutput = sGroundtruthOutput[0..$-2] ~ "\n ],\n" ~
        " \"information\": { \"numArticles\": " ~ to!string(sentencesPerArticle.length) ~
        ", \"sentences\": "~ to!string(sentencesPerArticle) ~
        " }\n}";

    } else if (this.mcArgs["format"] == "xml") {
      sSourceOutput ~= "\n</tokens>";
      sGroundtruthOutput ~= "\n</corrections>";
    }

    std.file.write(globalRawFilename, sRawOutput);
    std.file.write(globalSrcFilename, sSourceOutput);
    std.file.write(globalGrtFilename, sGroundtruthOutput);

    // Generate TrainingSet
    nArticleCounter = 0;
    if (this.bTrainingSet == true) {
      writeln("Start generation of training set");
      Array!string excludeForTrainingSet; // 1000, 10000, 100000, 600000

      this.mcArgs["mode"] = Variant("trainingset");

      foreach (i; iota(this.mFilenames.length).snck) {
        if ((((i+1) % 1000) != 0) && (((i+1) % 600_000) != 0)) {
          auto l = this.mFilenames[i];
          dstring readBuf = to!dstring(readText(l));
          auto content = readBuf.lineSplitter().array;

          for (size_t j = 0; j < content.length; j++) {
            while (indexOf(content[j], "  ", 0) !is -1)
              content[j] = content[j].replace("  ", " ");
          }

          // Generate the filenames
          Array!string srcPcs = l.split("/");
          string inpDirname = buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "raw", this.mcArgs["dataset"].get!string, srcPcs[srcPcs.length-2]);
          string srcDirname = buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "source", this.mcArgs["dataset"].get!string, srcPcs[srcPcs.length-2]);
          string grtDirname = buildPath(this.mcArgs["output_dir"].get!string, this.mcArgs["mode"].get!string, "groundtruth", this.mcArgs["dataset"].get!string, srcPcs[srcPcs.length-2]);
          if (!exists(inpDirname)) { mkdirRecurse(inpDirname); }
          if (!exists(srcDirname)) { mkdirRecurse(srcDirname); }
          if (!exists(grtDirname)) { mkdirRecurse(grtDirname); }
          copy(l, buildPath(inpDirname, srcPcs[srcPcs.length-1]));
          string srcFilename = buildPath(srcDirname, srcPcs[srcPcs.length-1]);
          string grtFilename = buildPath(grtDirname, srcPcs[srcPcs.length-1]);
          //writeln("Debug: srcFilename -> ", srcFilename);
          //writeln("Debug: grtFilename -> ", grtFilename);

          // Generate noise here
          Tuple!(dstring, SentenceRepresentation)[] pairs;

          foreach(s; content) {
            pairs ~= tuple(s, this.mNoiser.generateNoise(nArticleCounter, s));
          }
          SourceRepresentation[] srcTokens;
          GroundtruthRepresentation[] grtTokens;
          //int gIdx = 0;
          foreach(sIdx, e; pairs.enumerate(0)) {
            dstring s = e[0]; // This is the raw sentence
            SentenceRepresentation n = e[1]; // The sentence representation, created by the noiser

            // Write the input information
            ulong srcPosition = 0;
            for (size_t tIdx = 0; tIdx < n.getNumCurrentTokens(); tIdx++) {
              srcTokens ~= new SourceRepresentation(nArticleCounter, cast(ulong)sIdx, tIdx, srcPosition, n.tokens[tIdx], n.spaces[tIdx]);
              srcPosition += n.tokens[tIdx].length;
              if (n.spaces[tIdx]) {
                srcPosition += 1;
              }
            }

            // Create the groundtruth information
            //static auto rTokenize = ctRegex!r"\w+\-\w+|\w+'\w+|\w+|[^\w\s]";
            //static auto rTokenize = ctRegex!r"(?:\d+,\d+)|(?:[\w'\u0080-\u9999]+(?:[-]+[\w'\u0080-\u9999]+)+)|(?:[\w\u0080-\u9999]+(?:[']+[\w\u0080-\u9999]+)+)|\b[_]|(?:[_]*[\w\u0080-\u9999]+(?=_\b))|(?:[\w\u0080-\u9999]+)|[^\w\s\p{Z}]";
            Array!string inpTokens;
            foreach (t; matchAll(to!string(s), rTokenize)) { inpTokens.insertBack(t); }
            // We are using two variables here for the later introduction of categories like SPLIT, CONCATENATION and REPEAT
            ulong tIdx = 0;
            ulong ii = 0;
            ulong grtPosition = 0;
            while (ii < n.getNumCurrentTokens()) {
              ulong shift = 0;
              //TODO[FGRT]if (n.errors[ii] != ErrorTypes.NONE) {
              // Check whether this is a 'complex' type like SPLIT or REPEAT
              if (n.marks[ii] == MarkTypes.START) {
                // Find the END Mark
                while (n.marks[ii++] != MarkTypes.END) {
                  //ii++;

                  shift++;
                }
                --ii;
              }
              // Generate the groundtruth information
              grtTokens ~= new GroundtruthRepresentation(nArticleCounter, cast(ulong)sIdx, ii-shift, ii, grtPosition, to!dstring(inpTokens[tIdx]), n.errors[ii]);
              grtPosition += inpTokens[tIdx].length;
              for (int spaces = 0; spaces < shift; ++i) {
                grtPosition += n.spaces[spaces+ii] ? 1 : 0;
              }
              //TODO[FGRT]}
              // Increase all counters
              tIdx++;
              ii++;
            }


            // Write source and groundtruth information to files
            string sSrcOut;
            string sGrtOut;
            if (this.mcArgs["format"] == "json") {
              sSrcOut = "{ \"tokens\": [\n";
              foreach (idx, t; srcTokens.enumerate(0)) {
                // Some post corrections on the token data
                if (t.token == "\"") {
                  t.token = t.token.replace("\"", "\\\"");
                }
                if (t.token == "\\") {
                  t.token = t.token.replace("\\", "\\\\");
                }
                if (idx == (srcTokens.length - 1)) {
                  sSrcOut ~= format("  {\"id\": \"a%s.s%s.w%s\", \"token\": \"%s\", \"pos\": %d, \"length\": %d, \"space\": %s}\n", nArticleCounter, t.sid, t.id, to!string(t.token), t.pos, t.token.length, t.space);
                } else {
                  sSrcOut ~= format("  {\"id\": \"a%s.s%s.w%s\", \"token\": \"%s\", \"pos\": %d, \"length\": %d, \"space\": %s},\n", nArticleCounter, t.sid, t.id, to!string(t.token), t.pos, t.token.length, t.space);
                }
              }
              sSrcOut ~= "\n  ]\n}";
              sGrtOut = "{ \"corrections\": [\n";
              foreach (idx, t; grtTokens.enumerate(0)) {
                // Some post corrections on the token data
                if (t.correct == "\"") {
                  t.correct = t.correct.replace("\"", "\\\"");
                }
                if (t.correct == "\\") {
                  t.correct = t.correct.replace("\\", "\\\\");
                }
                if (t.id1 != t.id2) {
                  sGrtOut ~= format("  {\"affected-id\": \"a%s.s%s.w%s-a%s.s%s.w%s\", \"correct\": \"%s\", \"pos\": %d, \"length\": %d, \"type\": \"%s\"}", nArticleCounter, t.sid, t.id1, nArticleCounter, t.sid, t.id2, to!string(t.correct), t.pos, t.correct.length, TypeToName(t.error));
                } else {
                  sGrtOut ~= format("  {\"affected-id\": \"a%s.s%s.w%s\", \"correct\": \"%s\", \"pos\": %d, \"length\": %d, \"type\": \"%s\"}", nArticleCounter, t.sid, t.id1, to!string(t.correct), t.pos, t.correct.length, TypeToName(t.error));
                }
                if (idx != (grtTokens.length - 1)) {
                  sGrtOut ~= ",\n";
                } else {
                  sGrtOut ~= "\n";
                }
              }
              sGrtOut ~= "\n ]\n}";
            } else if (this.mcArgs["format"] == "xml") {
              sSrcOut = "<tokens>\n";
              foreach (idx, t; srcTokens.enumerate(0)) {
                // Some post corrections on the token data
                if (t.token == "\"") {
                  t.token = t.token.replace("\"", "\\\"");
                }
                if (t.token == "\\") {
                  t.token = t.token.replace("\\", "\\\\");
                }
                if (idx == (srcTokens.length - 1)) {
                  sSrcOut ~= format("  <st id=\"a%s.s%s.w%s\" token=\"%s\" pos=\"%d\" length=\"%d\" space=\"%s\"/>\n", nArticleCounter, t.sid, t.id, to!string(t.token), t.pos, t.token.length, t.space);
                } else {
                  sSrcOut ~= format("  <st id=\"a%s.s%s.w%s\" token=\"%s\" pos=\"%d\" length=\"%d\" space=\"%s\"/>\n", nArticleCounter, t.sid, t.id, to!string(t.token), t.pos, t.token.length, t.space);
                }
              }
              sSrcOut ~= "\n</tokens>";
              sGrtOut = "<corrections>\n";
              foreach (idx, t; grtTokens.enumerate(0)) {
                // Some post corrections on the token data
                if (t.correct == "\"") {
                  t.correct = t.correct.replace("\"", "\\\"");
                }
                if (t.correct == "\\") {
                  t.correct = t.correct.replace("\\", "\\\\");
                }
                if (t.id1 != t.id2) {
                  sGrtOut ~= format("  <correction affected-id=\"a%s.s%s.w%s-a%s.s%s.w%s\" correct=\"%s\" pos=\"%d\" length=\"%d\" type=\"%s\"/>\n", nArticleCounter, t.sid, t.id1, nArticleCounter, t.sid, t.id2, to!string(t.correct), t.pos, t.correct.length, TypeToName(t.error));
                } else {
                  sGrtOut ~= format("  <correction affected-id=\"a%s.s%s.w%s\" correct=\"%s\" pos=\"%d\" length=\"%d\" type=\"%s\"/>\n", nArticleCounter, t.sid, t.id1, to!string(t.correct), t.pos, t.correct.length, TypeToName(t.error));
                }
              }
              sGrtOut ~= "\n</corrections>";
            }

            // Write the information out
            std.file.write(srcFilename, sSrcOut);
            std.file.write(grtFilename, sGrtOut);

          }
          nArticleCounter += 1;
        }
      }
    }

  }

  private Array!string generateLinkFilenames(string sLinkFile) {
    auto linksContent = readText(sLinkFile);

    Array!string result = linksContent.lineSplitter().array;

    for (size_t i = 0; i < result.length; i++) {
      auto pieces = result[i].split("/"); // We are only interested in the last to pieces
      result[i] = buildPath(this.mcArgs["input_dir"].get!string, pieces[2], pieces[3]);
      //writeln("New path is: ", result[i]);
    }
    writeln("\tGenerated all input paths.");

    return result;
  }

  private Noiser mNoiser;
  private Config config;
  private Variant[string] mcArgs;
  private Array!string mFilenames;
  private int mModFlag;
  private bool bTrainingSet;
}
