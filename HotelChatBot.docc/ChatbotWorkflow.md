# ChatbotWorkflow

This article describes how the chatbot works.

## Overview

The chatbot follows a simple flow cycle. There are a couple of questions. Each question is for collecting data
we need to create a ``Booking``. A Booking is for a ``Guest`` and the Guest needs one or more ``Room``s. 
That is we first ask the user for its firstname and lastname. With these attributes we can create a first but
not complete Guest object. Than we ask for some dates for the Booking. With the dates we check if a room is available.
If the are available they are put to the Booking object and at the end the user is asked for a mail address. This is the 
last information to complete the Guest object. The user is asked for a confirmation and in the positive case we store 
the Guest and the Booking object into the database.

Here you can see the workflow:
![Flowchart of the chatbot main process](ChatbotWorkflow.svg)

## Topics

### <!--@START_MENU_TOKEN@-->Group<!--@END_MENU_TOKEN@-->

- <!--@START_MENU_TOKEN@-->``Symbol``<!--@END_MENU_TOKEN@-->
