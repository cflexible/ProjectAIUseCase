...
/**
 This is the main function of analysing the texts. Here we get one sentence. So we can first analyse the kind
 of the sentence before we analyse the content of the sentence.
*/
static private func analyseSentence(text: String) -> String {
    #if DEBUG
        NSLog("\(type(of: self)) \(#function)()")
    #endif

    // If we miss a model we return
    if classifierModel == nil || taggerModel == nil {
        return String("I'm sorry but I miss a NLP model, please ask the developer.")
    }

    let baseErrormessage = Translations().getTranslation(text: "We are sorry but I did not understand you.<br>")
    
    var classifierLabel = classifierModel!.predictedLabel(for: text)
    // We remember the text
    ClassifierHelper.addText(language: currentLanguage, text: text, classifierString: classifierLabel)
    print("Found classifier: \(classifierLabel ?? "")")
    if ["hasEnglishDates", "hasGermanDates", "hasUSDates"].contains(classifierLabel) {
        classifierLabel = "hasDates"
    }
    
    switch classifierLabel {
    case "hasNames":
        if workBooking.guest?.firstname?.count ?? 0 > 0 && workBooking.guest?.lastname?.count ?? 0 > 0 {
            return baseErrormessage + Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
        }
        let firstName: String = valueForNames(tagname: "first-name", text: text)
        let lastName:  String = valueForNames(tagname: "last-name", text: text)
        
        if firstName.count > 0 && lastName.count > 0 {
            workBooking.guest?.firstname = firstName
            workBooking.guest?.lastname  = lastName
            var positiveReturn = Translations().getTranslation(text: workflows[askedQuestion + 1].positiveAnswer ?? "")
            positiveReturn = positiveReturn.replacingOccurrences(of: "<firstName>", with: firstName)
            positiveReturn = positiveReturn.replacingOccurrences(of: "<lastName>", with: lastName)
            return positiveReturn
        }
        print(askedQuestion)
        return baseErrormessage + Translations().getTranslation(text: workflows[askedQuestion].negativeAnswer ?? "")
        
    case "hasMailaddress":
        let mail: String = Utilities.getMailAddressFromText(text) ?? ""
        ...
