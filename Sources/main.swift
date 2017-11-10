//
//  main.swift
//  hamwick
//
//  Created by jakeluck on 8/11/17.
//  Copyright © 2017 freetime. All rights reserved.
//

import Foundation


func s4(input: String) -> [NSRange] {
    let options: NSLinguisticTagger.Options =
        [.omitWhitespace, .omitWords, .joinNames]
    
    let scheme = NSLinguisticTagger.availableTagSchemes(forLanguage: "en")
    let tagger = NSLinguisticTagger(tagSchemes: scheme, options: Int(options.rawValue))
    
    tagger.string = input
    let range = NSRange(location: 0, length: input.utf16.count)
    var current_sentence: String = ""
    var result : [NSRange] = []
    
    tagger.enumerateTags(in: range, scheme: NSLinguisticTagSchemeNameTypeOrLexicalClass,options: options) {
        tag, tokenRange, sentenceRange, stop in
        let sentence = (input as NSString).substring(with: sentenceRange)
        if sentence != current_sentence {
            //print("\(token) \(tag):  \(sentence)")
            result.append(sentenceRange)
        }
        current_sentence = sentence
    }
    return result
}


func tag_them(input: String, tag_scheme: String = NSLinguisticTagSchemeNameTypeOrLexicalClass)
    -> [(token:String, tag:String, range:NSRange)] {
        let options: NSLinguisticTagger.Options =
            [ .omitWhitespace, .omitPunctuation, .joinNames ]
        
        let scheme = NSLinguisticTagger.availableTagSchemes(forLanguage: "en")
        let tagger = NSLinguisticTagger(tagSchemes: scheme, options: Int(options.rawValue))
        
        tagger.string = input
        let range = NSRange(location: 0, length: input.utf16.count)
        var result : [(String, String, NSRange)] = []
        
        tagger.enumerateTags(in: range, scheme: tag_scheme, options: options) {
            tag, tokenRange, sentenceRange, stop in
            let token = (input as NSString).substring(with: tokenRange)
            //print("\(token)(\(tag))", separator: " ", terminator: " ")
            result.append((token: token, tag: tag, range: tokenRange))
        }
        //print()
        return result
}

var skills = [
    "first_noun_last_noun": {
        (original: String) -> String in
        
        var seg = tag_them(input: original)
        let nouns = seg.filter {(_, tag, _) in tag == "Noun"}
        
        guard nouns.count > 2 else {
            print("*** not enough nouns to swap.")
            return original
        }
        
        let s1 = nouns.first!
        let s2 = nouns.last!
        
        let alt = NSMutableString(string: original)
        // replace back to front
        alt.replaceCharacters(in: s2.range, with: s1.token)
        alt.replaceCharacters(in: s1.range, with: s2.token)
        return (alt as String)
    },
    
    "last_two_words": {
        (original: String) -> String in
        
        var seg = tag_them(input: original, tag_scheme: NSLinguisticTagSchemeTokenType)
        
        guard seg.count > 2 else {
            print("*** not enough words to swap.")
            return original
        }
        
        let s1 = seg[seg.count-2]
        let s2 = seg.last!
        
        let alt = NSMutableString(string: original)
        // replace back to front
        alt.replaceCharacters(in: s2.range, with: s1.token)
        alt.replaceCharacters(in: s1.range, with: s2.token)
        return (alt as String)
    },

    "wrong_number": {
        (original: String) -> String in
        
        var seg = tag_them(input: original, tag_scheme: NSLinguisticTagSchemeLemma)
        let bes = seg.filter {(_, tag, _) in tag == "be"}
        
        guard seg.count > 1 else {
            print("*** not enough be(s) to change.")
            return original
        }
        
        let singular = ["is", "am", "be", "been", "being", "was"]
        let plural   = ["are", "were"]
        
        let alt = NSMutableString(string: original)
        for b in bes.reversed() {
            let (token, tag, range) = b
            var now = ""
            
            if singular.contains(token.lowercased()) {
                let r = Int(arc4random_uniform(UInt32(plural.count)))
                now = plural[r]
            } else {
                let r = Int(arc4random_uniform(UInt32(singular.count)))
                now = singular[r]
            }
            
            if CharacterSet.uppercaseLetters.contains(token.unicodeScalars.first!) {
                now = now.capitalized
            }
            alt.replaceCharacters(in: range, with: now)
        }
        return (alt as String)
    },
    
    "big_mess" : {
        (original: String) -> String in
        var seg = tag_them(input: original)
        return original
    },
]

func gen_pfa(infile: String, outfile: String) {
    guard let full = try? String(contentsOfFile: infile, encoding: .utf8) else {
        print("read \(infile) failed")
        return
    }
    
    let parsed = s4(input: full)
    
    //let small_change = skills["first_noun_last_noun"]!
    //let small_change = skills["wrong_number"]!
    let small_change = skills["last_two_words"]!
    
    var twin : [(String, String)] = []
    for i in 0..<parsed.count {
        let nsrange = parsed[i]
        let sentence = (full as NSString).substring(with: nsrange).trimmingCharacters(in: .whitespacesAndNewlines)
        let alt = small_change(sentence)
        twin.append((sentence, alt))
    }
    
    var wicked : [String] = []
    for i in 0..<twin.count {
        let (before, after) = twin[i]
        let r = Int(arc4random_uniform(UInt32(2)))
        if r == 0 {
            wicked.append("P1\t" + before)
            wicked.append("P2\t" + after)
            wicked.append("C1\n")
        } else {
            wicked.append("P1\t" + after)
            wicked.append("P2\t" + before)
            wicked.append("C2\n")
        }
    }
    
    let ready = wicked.joined(separator: "\n")

    do {
        try ready.write(toFile: outfile, atomically: true, encoding: .utf8)
    } catch {
        print("write \(outfile) failed")
        return
    }
}

var filename: String

//print(CommandLine.arguments)

switch CommandLine.argc {
case 2:
    filename = CommandLine.arguments[1]
default:
    print("Usage: hamwick <filename>")
    print("   creates <filename_pfa.utf8>\n")
    exit(EXIT_FAILURE)
}

gen_pfa(infile: filename, outfile: filename.appending("_pfa.utf8"))


