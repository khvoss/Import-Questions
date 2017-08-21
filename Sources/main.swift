/**
 * Copyright 2017 International Business Machines Corporation ("IBM")
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * http://www.apache.org/licenses/LICENSE-2.0
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Foundation
import SwiftyJSON
import CouchDB
import LanguageTranslatorV2

// file that the entries will be read from
let file = "triviaQuestions.txt"
// format for JSON being written to database
var entry = JSON.init(jsonArray:
    ["question":" ",
     "correctAnswer": " ",
     "incorrectAnswers": [" ", " ",  " "],
     "questionES":" ",
     "correctAnswerES": " ",
     "incorrectAnswersES": [" ", " ",  " "],
     "timesCorrect": 0,
     "timesAttempted": 0,
     "rand": 0])
var question: String
var correctAnswer: String
var incorrectAnswer1: String
var incorrectAnswer2: String
var incorrectAnswer3: String
var rand: CGFloat
var incorrectAnswerES1: String = ""
var incorrectAnswerES2: String = ""
var incorrectAnswerES3: String = ""
let translateGroup = DispatchGroup()


// function to split fields in an entry
func getSubstring(find: String, inString: String, last: Bool = false) -> String {
    var returnString = ""
    guard let index = inString.range(of: find) else {
        print("Couldn't find substring \(find) in \(inString)")
        return ""
    }
    let subString = inString.substring(from: index.upperBound)
    if !last{
        // use newline as delimiter
        guard let endIndex = subString.range(of: "\n") else {
            print("Couldn't find end of line in substring \(subString)")
            return ""
        }
        // cut field at newline, trim off any whitespace at the end
        returnString = subString.substring(to: endIndex.lowerBound).trimmingCharacters(in: .whitespaces)
    } else {
        // last field has newline stripped already, just trim whitespace
        returnString = subString.trimmingCharacters(in: .whitespaces)
    }
    return returnString
}

// connect to your database
func openDatabase() -> Database{
    let connProperties = ConnectionProperties(host: "**fill in host url**",
                                              port: Int16(443),
                                              secured: true,
                                              username:  "**fill in username**",
                                              password: "**fill in password**")
    let couchDBClient = CouchDBClient(connectionProperties: connProperties)
    let database = couchDBClient.database("trivia_questions")
    print("set up database from local")
    return database
}

// connect to your Watson Language Translator
func setupTranslate() -> LanguageTranslator{
    let username = "**fill in username**"
    let password = "**fill in password**"
    let languageTranslator = LanguageTranslator(username: username, password: password)
    languageTranslator.serviceURL = "https://gateway.watsonplatform.net/language-translator/api"
    return languageTranslator
}

// function to translate a string
func translateEntry(translateString: String, translateLang: String, translator: LanguageTranslator, callback: @escaping (TranslateResponse) -> Void){
    translateGroup.enter()
    let failure = { (error: Error) in print(error) }
    translator.translate(translateString, from: "en", to: translateLang, failure: failure, success: callback)
}

// function to write to the database
func writeEntry(inDatabase: Database, entry: JSON){
    inDatabase.create(entry) {
        id, rev, document, error in
        guard error == nil else{
            print("error adding document")
            return
        }
    }
}

do{
    var database = openDatabase()
    var languageTranslator = setupTranslate()
    if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let path = dir.appendingPathComponent(file)
        //read from file
        let text = try String(contentsOf: path, encoding: String.Encoding.utf8)
        var timeout = DispatchTime.now()
        // split the entries by two newlines
        let sections = text.components(separatedBy: "\n\n")
        // process each entry
        for section in sections {
            if !section.trimmingCharacters(in: .whitespaces).isEmpty {
                // parse the entry
                question = getSubstring(find: "Question:", inString: section)
                correctAnswer = getSubstring(find: "CorrectAnswer:", inString: section)
                incorrectAnswer1 = getSubstring(find: "IncorrectAnswer1:", inString: section)
                incorrectAnswer2 = getSubstring(find: "IncorrectAnswer2:", inString: section)
                incorrectAnswer3 = getSubstring(find: "IncorrectAnswer3:", inString: section, last: true)
                if (question.isEmpty || correctAnswer.isEmpty || incorrectAnswer1.isEmpty || incorrectAnswer2.isEmpty ||   incorrectAnswer3.isEmpty)
                {
                    print("error reading question \(section), question discarded")
                } else {
                    // set up the JSON from the parsed entry
                    entry["question"] = JSON(question)
                    translateEntry(translateString: question, translateLang: "es", translator: languageTranslator)  {
                        translation in
                        if let translatedText = translation.translations.first {
                            entry["questionES"] = JSON(translatedText.translation)
                        }
                        translateGroup.leave()
                    }
  
                    entry["correctAnswer"] =  JSON(correctAnswer)
                    translateEntry(translateString: correctAnswer, translateLang: "es", translator: languageTranslator)  {
                        translation in
                        if let translatedText = translation.translations.first {
                            entry["correctAnswerES"] = JSON(translatedText.translation)
                        }
                        translateGroup.leave()
                    }
                    
                    entry["incorrectAnswers"] = JSON([incorrectAnswer1, incorrectAnswer2,  incorrectAnswer3])
                    translateEntry(translateString: incorrectAnswer1, translateLang: "es", translator: languageTranslator)  {
                        translation in
                        if let translatedText = translation.translations.first {
                            incorrectAnswerES1 = translatedText.translation
                        }
                        translateGroup.leave()
                    }
                    translateEntry(translateString: incorrectAnswer2, translateLang: "es", translator: languageTranslator)  {
                        translation in
                        if let translatedText = translation.translations.first {
                            incorrectAnswerES2 = translatedText.translation
                        }
                        translateGroup.leave()
                    }
                    translateEntry(translateString: incorrectAnswer3, translateLang: "es", translator: languageTranslator)  {
                        translation in
                        if let translatedText = translation.translations.first {
                            incorrectAnswerES3 = translatedText.translation
                        }
                        translateGroup.leave()
                    }
                    
                    rand = (CGFloat(arc4random())/CGFloat(UInt32.max))
                    entry["rand"] = JSON(rand)
      
                    //wait for all the translations to finish
                    timeout = DispatchTime.now() + .seconds(5)
                    if translateGroup.wait(timeout: timeout) == .timedOut {
                        print("Request timed out")
                    }
                    entry["incorrectAnswersES"] = JSON([incorrectAnswerES1, incorrectAnswerES2,  incorrectAnswerES3])
                    //print(entry)
                    writeEntry(inDatabase: database, entry: entry)
                }
            }
         }
    }
} catch let error {
    print(error.localizedDescription)
}

