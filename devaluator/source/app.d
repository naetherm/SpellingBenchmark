// Copyright 2019, University of Freiburg.
// Chair of Algorithms and Data Structures.
// Markus Näther <naetherm@informatik.uni-freiburg.de>

module devaluator.app;

import devaluator.evaluator: Evaluator;

import std.stdio;
import std.container;
import std.string;
import std.variant;
import darg;
import vibe.d;

struct Options {

}

immutable usage = usageString!Options("devaluator");
immutable help = helpString!Options;

// Necessary for unit testing
version (unittest) {

} else {

/*
int main(string[] args)
{
	Options parser;

	try {
		parser = parseArgs!Options(args[1..$]);
	} catch (ArgParseError e) {
		writeln(e.msg);
		writeln(usage);

		return 1;
	} catch (ArchParseHelp e) {
		writeln(usage);
		writeln(help);

		return 0;
	}

	// Array, containing all options that are relevant
	Variant[string] opts;

	return 0;
}
*/

import vibe.http.router;
import vibe.web.rest;


interface EvaluationAPI {

	@path("/api/v1/evaluate")
	@method(HTTPMethod.POST)
	dstring evaluate(dstring langCode, dstring path);
}

class EvaluationAPIImplentation : EvaluationAPI {

	this() {
		this.evaluator = new Evaluator;
	}

	dstring evaluate(dstring langCode, dstring path) {
		logInfo(format("Received new input on path: %s", to!string(path)));
		return this.evaluator.evaluate(langCode, path);
	}

	Evaluator evaluator;
}


int main(string[] args) {
	auto router = new URLRouter;
	router.registerRestInterface(new EvaluationAPIImplentation());

	auto settings = new HTTPServerSettings;
	settings.port = 1338;
	settings.bindAddresses = ["0.0.0.0"];

	listenHTTP(settings, router);

	logInfo("Please open http://127.0.0.1:1338/ in your browser.");

	runTask({
		auto client = new RestInterfaceClient!EvaluationAPI("http://0.0.0.0:1338/");
	});

	runApplication();

	return 0;
}

}
