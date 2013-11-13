//
//  opts arguments
//  --------------------------------------------------------
//  onSearch*     : function, returing candidates(string array) when searching with word.
//                  function format is search(word, callback), and callback format is callback(list).
//  onSelect      : function, called when selecting suggest word.
//                  function format is select(word)
//  classSuggest  : default is ""
//  classSelect   : default is "select"
//  interval      : default is 500 (ms)
//  minLength     : default is 1 (letter)
//  topDiff       : default is 10(px)
//  leftDiff      : default is 0(px)
//
(function ($) {
  var KEYS = {
    TAB: 9,
    RETURN: 13,
    ESC: 27,
    UP: 38,
    DOWN: 40
  };

  $.fn.suggest = function (opts) {
    if (!opts || typeof opts.onSearch != "function") {
      throw "opts.onSearch must be function";
    }

    var defaults = {
      onSelect: function () { },
      classSuggest: "",
      classSelect: "select",
      interval: 500,
      minLength: 1,
      topDiff: 10,
      leftDiff: 0
    };
    opts = $.extend(defaults, opts);

    // variables
    // -------------------------------------------------------------------------------------
    var onSearch = opts.onSearch;
    var onSelect = opts.onSelect;
    var classSuggest = opts.classSuggest;
    var classSelect = opts.classSelect;
    var interval = opts.interval;
    var minLength = opts.minLength;
    var topDiff = opts.topDiff;
    var leftDiff = opts.leftDiff;

    var input = this;
    var $input = $(this);
    var $suggestArea = null;
    var oldText = "";       // old search text.
    var backupText = null;     // input text for restore.
    var timerId = null;
    var suggestList = [];
    var activePosition = null;

    // methods
    // -------------------------------------------------------------------------------------

    var observeText = function () {
      var text = $input.val();
      if (trim(text) != trim(oldText)) {
        oldText = text;
        search(trim(text));
      }
      if (timerId) {
        clearTimeout(timerId);
      }
      timerId = setTimeout(observeText, interval);
    };

    var search = function (text) {
      if (text == "" || text.length < minLength) {
        clearSuggestArea();
        return;
      }
      onSearch(text, onFinishSearch);
    };

    var onFinishSearch = function (list) {
      list = list || [];
      if (!$.isArray(list)) {
        throw "search result list is not array";
      }
      clearSuggestArea();
      createSuggestArea(list);
    };

    var changeActive = function (index) {
      $suggestArea.find("div:eq(" + index + ")").attr("class", classSelect);
      var text = suggestList[index];
      oldText = text;
      $input.val(text).focus();
    };

    var changeUnactive = function () {
      $suggestArea.find("." + classSelect).attr("class", "");
    };

    var clearSuggestArea = function () {
      $suggestArea.hide().empty();
      suggestList = [];
      activePosition = null;
    };

    var createSuggestArea = function (list) {
      backupText = $input.val();

      $.each(list, function (i, item) {
        suggestList.push(item);
        $('<div />').text(item).appendTo($suggestArea);
      });

      if (suggestList.length > 0) {
        $suggestArea.css({ top: getSuggestAreaTop(), left: getSuggestAreaLeft() }).show();
      }
    };

    var restoreBackup = function () {
      oldText = backupText;
      $input.val(backupText);
    };

    var moveEnd = function () {
      if (input.createTextRange) {
        input.focus(); // Opera
        var range = input.createTextRange();
        range.move('character', input.value.length);
        range.select();
      } else if (input.setSelectionRange) {
        input.setSelectionRange(input.value.length, input.value.length);
      }
    };

    var getSuggestAreaTop = function () {
      return $input.offset().top + $input.height() + topDiff;
    };

    var getSuggestAreaLeft = function () {
      return $input.offset().left + leftDiff;
    };

    var initSuggestArea = function () {
      $suggestArea = $('<div />')
        .attr({ id: createSuggestId(), "class": classSuggest })
        .css({ display: "none" })
        .delegate("div", "mouseover", function () {
          restoreBackup();
          changeUnactive();
          activePosition = $suggestArea.find("div").index(this);
          $(this).attr("class", classSelect);
        })
        .delegate("div", "mouseout", function () {
          changeUnactive();
        })
        .delegate("div", "click", function () {
          activePosition = $suggestArea.find("div").index(this);
          changeActive(activePosition);
          moveEnd();
          onSelect(oldText);
        })
        .appendTo("body");
    };

    var initInput = function () {
      oldText = $input.val();

      $input.focus(observeText);
      $input.blur(function () {
        oldText = $input.val();
        if (!timerId) {
          clearTimeout(timerId);
        }

        setTimeout(clearSuggestArea, 200);  // for capture click event of suggest item
      });

      initKeyEvent();
    };

    var initKeyEvent = function () {
      var keyevent = 'keydown';
      if (window.opera || (navigator.userAgent.indexOf('Gecko') >= 0 && navigator.userAgent.indexOf('KHTML') == -1)) {
        keyevent = 'keypress';
      }

      $input.bind(keyevent, function (e) {
        if (!timerId) {
          timerId = setTimeout(observeText, interval);
        }

        var keyCode = e.keyCode;

        // if press UP when suggest area is none, search again.
        if (suggestList.length == 0 && keyCode == KEYS.DOWN) {
          e.preventDefault();
          oldText = "";
          return;
        }

        if (suggestList.length > 0 && $.inArray(keyCode, [KEYS.RETURN, KEYS.ESC, KEYS.UP, KEYS.DOWN]) != -1) {
          if (keyCode == KEYS.RETURN) {
            if (activePosition != null) {
              e.preventDefault();
              oldText = suggestList[activePosition];
              $input.val(oldText);
              onSelect(oldText);
            }
            clearSuggestArea();
            moveEnd();
          } else if (keyCode == KEYS.ESC) {
            e.preventDefault();
            clearSuggestArea();
            restoreBackup();
            if (window.opera) {
              setTimeout(moveEnd, 5);
            }
          } else {  // UP, DOWN
            e.preventDefault();
            changeUnactive();
            if (keyCode == KEYS.UP) {
              activePosition = activePosition == null ? suggestList.length - 1 : activePosition - 1;
            } else {
              activePosition = activePosition == null ? 0 : activePosition + 1;
            }

            if (activePosition >= 0 && activePosition < suggestList.length) {
              changeActive(activePosition);
            } else {
              activePosition = null;
              restoreBackup();
            }
          }
        }
      });
    };

    // main
    // -------------------------------------------------------------------------------------
    initSuggestArea();
    initInput();
  };

  // utils
  // -------------------------------------------------------------------------------------
  var trim = function (str) {
    if (typeof str != "string") return str;
    return str.replace(/^[\s　]+|[\s　]+$/g, "");
  };

  var createSuggestId = (function () {
    var no = 0;
    return function () {
      no += 1;
      return "__suggest__" + no;
    };
  })();

})(jQuery);