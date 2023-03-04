# DatabaseStructure

This article describes the database in a class diagram.

## Overview

The used database for thie proof of concept application is a SQLite standard database which is automatically 
created from a core database definition. Because in this application the functionality of automatic class
generation is used, there is no special class description. So the db classes are described in this article.

Overview class diagram of core data (In the past XCode had an automatic diagram generation but this is not available anymore.)
![Class diagram of core database](HotelbookingChatbotClassdiagram.svg)

``Booking``:                Main class for storing a booking, connected to a Guest, Rooms and Parkingplaces

``Guest``:                  Main class for storing informations about a guest. Not all defined properties are used in the POC.

``Room``:                   Main class for storing rooms. A room can connected to bookings and with the booking the booked dates are clear.

``RoomImage``:              Main class for storing room images. This entity is not used at the moment, but can used to present room images to the user.

``Parkingplace``:           Main class for storing parking places with some attributes like having a charge station or not. It can also conect to a booking.

``Workflow``:               Main class for storing the workflows. With this you can add or remove steps of asking the guest for information.

``Translation``:            Main class for storing translations which are used when workflow texts are shown to the user.

``Classifierdefinitions``:  Main class for storing texts with classifications to reteach the ML classifying model.

``Wordtaggingdefinitions``: Main class for storing words with tags for retaeching the ML tagging model.

## Topics

### Generated database classes without documentation

- ``Booking`` 
- ``Guest``
- ``Room``
- ``RoomImage``
- ``Parkingplace``
- ``Workflow``
- ``Translation``
- ``Classifierdefinitions``
- ``Wordtaggingdefinitions``

