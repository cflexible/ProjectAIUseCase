# ``HotelChatBot``

This chatbot is a proof of concept how a chat bot can build up as a Mac OS app with the Apple development included tools for machine learning. 

## Overview

The hotel chatbot is a more or less single window application. The main functionality is that a user (``Guest``) can write some information
in natural language and the app analyses this information and tries to fill in a ``Booking`` for that guest. There are a couple of questions 
which are needed to ask the guest for some information. When the information the guest gave the chatbot is recognized as information needed
for a booking, these information is add to a booking object and when all neccessary information is collected it is present to the guest so
he can confirm it. The presented view is of HTML so it is easy to change the styles and images to own ones.

![Use case of the chatbot.](HotelbookingChatbotUseCase.svg)

The text analysis in ``ChatController`` has two steps. The first step analyses whole sentences. With this we can already collect information, e.g. a positive
answer for breakfast can classified here. Other more complex things need a second step for analysing the words of the sentencs. For example
if we had recognized that a sentence contains names we want to know which one is a firstname and which one is a lastname. Also a differentiating
of genders could be possible. There could be some inaccuracies. So for some texts the hypotheses of the words are used to get the right one.

For training purposes all the individual user input is stored in two tables. So when the app is closed by the user from these tables four files 
per language are created, two for sentence classification and two for word tagging. These files can be used as a base for trainingsdata but 
you have to check the classifications abnd taggings before you use them for training. In these files the collected data is splitt into trainings
and test data in 75:25%.

The models can used in the Create ML developer tool (https://developer.apple.com/machine-learning/create-ml/) to generate new model files.
The app also supports multi languages. A small group of texts are used in the standard translation Localizable.strings file while all the other 
translations should stored in the database.

An example view from a beginning of a chat:
![An example view from a beginning of a chat.](HotelChatbotSample.png)


## Topics

### Essentials

- <doc:ChatbotWorkflow>
- <doc:DatabaseStructure>
- <doc:HowToAdjust>

### Main Classes

- ``AppDelegate``
- ``ViewController``
- ``OutputViewGenerator``
- ``ChatController``
- ``Translations``
- ``HelpViewController``
- ``LanguageWindowController``
- ``LanguageChangeDelegate``
- ``DatastoreController``
- ``Utilities``
- ``DataLoad``
- ``ClassifierHelper``
- ``TaggerHelper``
