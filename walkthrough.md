# API Modes Implementation Walkthrough

This document outlines the changes made to support multiple API modes ("OpenAI Compatible" and "Vertex AI") in the NexAI application.

## Overview
The goal was to provide users with the flexibility to choose their preferred AI model provider, specifically adding support for Google's Vertex AI alongside the existing OpenAI-compatible functionality.

## Changes Made

### 1. Configuration Layer (`SettingsProvider.dart`)
- **Added new properties:** `apiMode`, `vertexProjectId`, and `vertexLocation`.
- **Created getters and setters** for these new properties to manage state and notify listeners.
- **Implemented persistence** using `SharedPreferences` to ensure user selections are saved across sessions.

### 2. UI Layer 

#### `SettingsPage.dart`
- **Updated Desktop (Fluent UI) and Mobile (Material 3) layouts.**
- **Added an API Mode selector:** A dropdown/combobox allowing users to switch between 'OpenAI Compatible' and 'Google Vertex AI'.
- **Conditional Field Display:**
  - When **OpenAI** is selected, the standard `Base URL` and `API Key` fields are shown.
  - When **Vertex** is selected, the `Base URL` field is hidden. New fields for `Project ID` and [Location](file:///f:/Repositories/GitHub/NexAI/lib/providers/settings_provider.dart#333-338) are displayed.
  - The `API Key` field description dynamically changes to clarify its usage in Vertex mode (Standard Mode vs. Express Mode).

#### `ChatPage.dart`
- **Updated [_send](file:///f:/Repositories/GitHub/NexAI/lib/pages/chat_page.dart#92-152) method:** Modified to pass the newly introduced settings (`apiMode`, `vertexProjectId`, `vertexLocation`) from [SettingsProvider](file:///f:/Repositories/GitHub/NexAI/lib/providers/settings_provider.dart#4-339) to the [ChatProvider](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#24-548)'s [sendMessage](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#144-184) function.

### 3. Service Layer (`ChatProvider.dart`)
- **Updated Method Signatures:** [sendMessage](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#144-184), [resendMessage](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#185-223), [editAndResendMessage](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#224-264), and [_performApiCall](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#265-328) now accept `apiMode`, `vertexProjectId`, and `vertexLocation`.
- **Branched API Logic:** The core [_performApiCall](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#265-328) method now routes requests based on the selected `apiMode`:
  - [_performOpenAiCall](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#329-421): Contains the existing logic for handling OpenAI-compatible requests.
  - [_performVertexCall](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#422-541): A newly implemented method specifically for formatting and sending requests to Vertex AI.
- **Vertex AI Implementation Details ([_performVertexCall](file:///f:/Repositories/GitHub/NexAI/lib/providers/chat_provider.dart#422-541)):**
  - **Payload Construction:** Maps the system prompt to `systemInstruction` and formats the conversation history into the `contents` array with `"role": "user"` and `"role": "model"`.
  - **URL Construction:** Dynamically builds the endpoint URL based on whether `vertexProjectId` is provided:
    - **Express Mode (No Project ID):** Uses the API key as a query parameter.
    - **Standard Mode:** Uses the Project ID and Location, passing the API key as a Bearer token in the `Authorization` header.
  - **SSE Parsing:** Implements Server-Sent Events (SSE) parsing by appending `?alt=sse` to the URL. This allows for streaming responses, similar to the OpenAI implementation, by reading chunks and extracting text from `candidates[0].content.parts[0].text`.

## Validation
- The application logic has been successfully structured to handle both API formats.
- The UI dynamically adapts to the selected mode.
- The application compiles successfully.
