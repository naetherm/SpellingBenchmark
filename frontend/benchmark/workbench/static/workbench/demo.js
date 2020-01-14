var Visualizer = (function() {
  function Visualizer() {

  };
  Visualizer.render = function(tokens, errrs, conns, sourcy, programName, corrected) {
    var out = {
      __content: "",
      append: function(s) {
        this.__content += s;
      }
    }

    var identifier_ = programName + "_" + sourcy + "_";

    var connections = conns.split("|");

    var shift_ = 0;
    for (var _tidx in tokens) {
      _tidx = parseInt(_tidx);
      if (sourcy != 'predict') {
        if (sourcy == 'grt') {
          out.append("<mark class=\""+errrs[_tidx]+"\" id=\"" + identifier_ + (_tidx+shift_)  + "\" data-id=\"" + identifier_ + (_tidx+shift_)  + "\" data-entity=\""+sourcy+"\">"+tokens[_tidx]+"</mark>");
        } else {
          out.append("<mark class=\"\" id=\"" + identifier_ + (_tidx+shift_)  + "\" data-id=\"" + identifier_ + (_tidx+shift_)  + "\" data-entity=\""+sourcy+"\">"+tokens[_tidx]+"</mark>");
        }
      } else {
        if (corrected[_tidx] === 'true') {
          out.append("<mark class=\"\" id=\"" + identifier_ + (_tidx+shift_)  + "\" data-id=\"" + identifier_ + (_tidx+shift_)  + "\" data-entity=\""+sourcy+"_green"+"\">"+tokens[_tidx]+"</mark>");
        } else {
          out.append("<mark class=\"\" id=\"" + identifier_ + (_tidx+shift_)  + "\" data-id=\"" + identifier_ + (_tidx+shift_)  + "\" data-entity=\""+sourcy+"_red"+"\">"+tokens[_tidx]+"</mark>");
        }
      }
      
    }

    // 
    //if (sourcy == 'grt') {
    //  var connections = conns.split("|");
    //  for (var c in connections) {
    //    var grt2src = connections[c].split("->");
    //    var src_ = grt2src[1].split(",");
//
    //    for (var sidx in src_) {
    //      console.log("#"+programName+"_source_"+src_[sidx]);
    //      var srcItem = $("#"+programName+"_source_"+src_[sidx]);
    //      //srcItem[0].classList.add(errrs[parseInt(grt2src[0])]);
    //      srcItem[0].className += errrs[parseInt(grt2src[0])];
    //      console.log(errrs[parseInt(grt2src[0])]);
    //    }
    //  }
    //}

    return out.__content;
  }
  Visualizer.renderArrows = function(cntr, appendContainer, prdSrcConnections, prdGrtConnections, programName, className) {
    var prdSrcLines = prdSrcConnections.split("|");
    var prdGrtLines = prdGrtConnections.split("|");
    for (var c in prdSrcLines) {
      var prd_src = prdSrcLines[c].split("->");
      var src_ = prd_src[1].slice(1, -1).split(",");
      
      var prdItem = $( "#" + programName + "_predict_" + prd_src[0] );
      for (var sidx in src_) {
        
        if (src_[sidx] !== "") {
          var srcItem = $( "#" + programName + "_source_" + src_[sidx].replace(" ", "") );

          var arrow = new SVGArrow(cntr, prdItem, srcItem, true);
          appendContainer.appendChild(arrow.generate());
        }
      }
    }
    for (var c in prdGrtLines) {
      var prd_grt = prdGrtLines[c].split("->");
      var grt_ = prd_grt[1].slice(1, -1).split(",");
      
      var prdItem = $( "#" + programName + "_predict_" + prd_grt[0] );
      for (var gidx in grt_) {
        
        if (grt_[gidx] !== "") {
          var srcItem = $( "#" + programName + "_grt_" + grt_[gidx].replace(" ", "") );

          try {
            var arrow = new SVGArrow(cntr, srcItem, prdItem, false);
            appendContainer.appendChild(arrow.generate());
          }
          catch(err) {
            console.log("Unable to match entries! TODO(naetherm): Add more logging information.");
          }
        }
      }
      
    }
  }
  return Visualizer;
}());

var BenchmarkViz = function() {
  function BenchmarkViz(programs, optionals) {
    var _this = this;
    this.onStart = function () {};
    this.onSuccess = function () {};
    this.programs = programs;
    if (optionals.onStart) { this.onStart = optionals.onStart; }
    if (optionals.onSuccess) { this.onSuccess = optionals.onSuccess; }
    window.addEventListener('resize', function() { _this.svgResizeAll(_this.programs); })
  };
};


BenchmarkViz.prototype.svgResizeAll = function(programs) {
  for (var _i = 0;_i < progams.length; _i++) {
    var task = programs[_i];
    var container = this.container(task);
    var svgContainer = this.svgContainer(task);
    svgContainer.setAttribute('width', "" + container.scrollWidth);
    svgContainer.setAttribute('height', "" + container.scrollHeight);
  }
};

BenchmarkViz.prototype.container = function(program) {
  return document.querySelector(".program." + program + " .text-container");
};
BenchmarkViz.prototype.svgContainer = function(program) {
  return document.querySelector(".program." + program + " .svg-container");
};

BenchmarkViz.prototype.render = function(programs, sentenceID, sentences, predictions) {
  // TODO: Keep in mind that all parameters will be JSON!
  if (sentenceID != -1) {
    for (var _p of programs) {
      this.svgContainer(_p).textContent = "";
      // Create for program
      if (predictions[_p].length > 0) {
        this.container(_p).innerHTML = "<h4>" + _p + "</h4>" + Visualizer.render(sentences[0], sentences[2], sentences[3], "source", _p) + "<br><br>";
        
        this.container(_p).insertAdjacentHTML('beforeend', Visualizer.render(predictions[_p][0].tokens, sentences[2], sentences[3], "predict", _p, predictions[_p][0].corrected) + "<br><br>");
        
        this.container(_p).insertAdjacentHTML('beforeend', Visualizer.render(sentences[1], sentences[2], sentences[3], "grt", _p));

        var connections = sentences[3].split("|");
        for (var c in connections) {
          var grt2src = connections[c].split("->");
          var src_ = grt2src[1].split(",");
          for (var sidx in src_) {
            var srcItem = $("#"+_p+"_source_"+src_[sidx]);
            //srcItem[0].classList.add(errrs[parseInt(grt2src[0])]);
            srcItem[0].className += sentences[2][parseInt(grt2src[0])];
          }
        }

        // The marks are drawn noww, draw the arrows!
        Visualizer.renderArrows(this.container(_p), this.svgContainer(_p), predictions[_p][0].src, predictions[_p][0].grt, _p);
      }
    }
  }
};

var ProgramViz = function() {
  function ProgramViz() {
    var _this = this;
    this.onStart = function () {};
    this.onSuccess = function () {};
    
  }
}

ProgramViz.prototype.container = function(aidx_sidx) {
  return document.querySelector(".sentence"+aidx_sidx+" .text-container");
}

ProgramViz.prototype.svgContainer = function(aidx_sidx) {
  return document.querySelector(".sentence"+aidx_sidx+" .svg-container");
}

ProgramViz.prototype.render = function(program, sentences, predictions) {
  // Loop through all sentences
  for (var sidx in sentences) {
    this.svgContainer(sidx).textContent = "";

    this.container(sidx).innerHTML = "<br><br>" + Visualizer.render(sentences[sidx][0], sentences[sidx][2], sentences[sidx][3], "source", "a"+sidx) + "<br><br>";

    this.container(sidx).insertAdjacentHTML('beforeend', Visualizer.render(predictions[sidx].tokens, sentences[sidx][2], sentences[sidx][3], "predict", "a"+sidx, predictions[sidx].corrected) + "<br><br>");
        
    this.container(sidx).insertAdjacentHTML('beforeend', Visualizer.render(sentences[sidx][1], sentences[sidx][2], sentences[sidx][3], "grt", "a"+sidx));

    
    var connections = sentences[sidx][3].split("|");
    for (var c in connections) {
      var grt2src = connections[c].split("->");
      var src_ = grt2src[1].split(",");
      for (var sid in src_) {
        var srcItem = $("#"+"a"+sidx+"_source_"+src_[sid]);
        //srcItem[0].classList.add(errrs[parseInt(grt2src[0])]);
        srcItem[0].className += sentences[sidx][2][parseInt(grt2src[0])];
      }
    }

    // The marks are drawn noww, draw the arrows!
    Visualizer.renderArrows(this.container(sidx), this.svgContainer(sidx), predictions[sidx].src, predictions[sidx].grt, "a"+sidx);
  }
}


var SVGArrow = function(container, markFrom, markTo, isDotted, optionals) {
  //function SVGArrow(container, markFrom, markTo, optionals) {
    this.classNames = [];
    this.container = container;
    this.markFrom = markFrom;
    this.markTo = markTo;
    this.isDotted = isDotted;
    this.label = "";//optionals.label || "";
    //this.marker =  optionals.marker;
    this.height = 3;//optionals.height || (this.label.length === 0) ? 3 : 1;
  //};
};

SVGArrow.prototype._el = function(tag, options) {
  if (options === void 0) { options = {}; }
  var _a = options.classnames, classnames = _a === void 0 ? [] : _a, _b = options.attributes, attributes = _b === void 0 ? [] : _b, _c = options.style, style = _c === void 0 ? [] : _c, _d = options.children, children = _d === void 0 ? [] : _d, text = options.text, id = options.id, xlink = options.xlink;
  var ns = 'http://www.w3.org/2000/svg';
  var nsx = 'http://www.w3.org/1999/xlink';
  
  var el = document.createElementNS(ns, tag);

  classnames.forEach(function (name) { return el.classList.add(name); });
  attributes.forEach(function (_a) {
    var attr = _a[0], value = _a[1];
    return el.setAttribute(attr, value);
  });
  if (xlink) {
    el.setAttributeNS(nsx, 'xlink:href', xlink);
  }
  if (id) {
    el.id = id;
}

  return el;
};
SVGArrow.prototype.generate = function() {
  var randName = Math.random().toString(36).substr(2, 8);
  var startX = (this.markFrom.offset().left - this.container.getBoundingClientRect().left) + (this.markFrom.width() / 2) + 4;
  var startY = (this.markFrom.offset().top - this.container.getBoundingClientRect().top);
  var endX = (this.markTo.offset().left - this.container.getBoundingClientRect().left) + (this.markTo.width() / 2) + 4;
  var endY = (this.markTo.offset().top - this.container.getBoundingClientRect().top) + this.markTo.height() + 8;

  var curve = "M"+startX+","+startY+" L"+endX+","+endY;
  if (this.isDotted) {
    return this._el("path", {
      id: "arrow-" + randName,
      classnames: ['displacy-arc'],
      attributes: [
        ['d', curve],
        ['stroke-width', '1px'],
        ['fill', 'none'],
        ['stroke', 'green'],
        ['stroke-dasharray', "2"]
      ]
    });
  } else {
    return this._el("path", {
      id: "arrow-" + randName,
      classnames: ['displacy-arc'],
      attributes: [
        ['d', curve],
        ['stroke-width', '1.5px'],
        ['fill', 'none'],
        ['stroke', 'currentColor']
      ]
    });
  }
};