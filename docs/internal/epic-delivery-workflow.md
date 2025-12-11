# Cross-Team Epic Delivery Workflow

This guide documents the optimal steps to create and work on Feature Epics in a collaborative way.

## Table of Contents

- [Cross-Team Epic Delivery Workflow](#cross-team-epic-delivery-workflow)
  - [Table of Contents](#table-of-contents)
  - [1. Epic Creation (Product / Dev / Design)](#1-epic-creation-product--dev--design)
  - [2. Design Exploration Phase](#2-design-exploration-phase)
  - [3. Final Design Approval \& Handoff](#3-final-design-approval--handoff)
  - [4. Development Planning](#4-development-planning)
  - [5. Design QA (Post-Implementation Review)](#5-design-qa-post-implementation-review)
  - [6. Epic Completion](#6-epic-completion)
  - [TLDR Summary Workflow (High-Level)](#tldr-summary-workflow-high-level)

## 1. Epic Creation (Product / Dev / Design)

* An **EPIC** is created for any new feature or major improvement (by product, dev or design teams).
* The EPIC includes:
    * Feature requirements
    * High-level scope
    * Known constraints or assumptions
* The epic is assigned to the **Design Team** with the label **<code>needs-design</code>**.


## 2. Design Exploration Phase

* The designer changes the epic status to **“In Progress”** once exploration begins.
* The designer starts drafting early concepts / prototypes.
* The designer is responsible for **pinging the Dev owner** early to initiate collaboration.
* Multiple review iterations may happen with: 
    * Dev / Product / (Optionally) other stakeholders (eg QA engineers)
* Syncs may be:
    * **Async** (chat / comments) / **Sync calls**, as needed
* Communication should be **frequent**, potentially more than once per week for complex features.


## 3. Final Design Approval & Handoff

* Last meeting to present the final design
* Once iterated and aligned, the final design direction is agreed by:
    * Design / Product / Dev
* The designer prepares and delivers the **Figma handoff package**.
* The designer **removes the <code>needs-design</code> label** from the epic.
* The designer **pings the Dev team** (in the same epic) to indicate the feature is ready for implementation.


## 4. Development Planning

* The Dev owner reviews the final design.
* The Dev owner breaks down the epic into **small, actionable subtasks**.
* Subtasks include:
    * UI components / Interactions / Edge states
    * Integration work
    * Non-visual logic affected by UI
    * Automation test to be implemented by a QA engineer
    * Design QA task
* The Dev owner assigns subtasks within the team (if needed) and starts implementation.
* It should have acceptance criteria


## 5. Design QA (Post-Implementation Review)

* Once the implementation is complete, **Dev notifies Design**.
* Designer reviews the built feature to ensure:
    * Visual fidelity
    * Correct interactions
    * Proper responsive handling
    * Consistency with the agreed design
* Any necessary follow-ups are captured as subtasks and addressed by Dev.


## 6. Epic Completion

* When:
    * All dev subtasks are done
    * Design QA is approved
    * Product is aligned

* The epic is marked as **Completed** and closed.


## TLDR Summary Workflow (High-Level)

1. <strong>Epic created -> assigned to Design with <code>needs-design</code></strong>
2. <strong>Design exploration -> prototypes -> early dev syncs</strong>
3. <strong>Final design agreed -> Figma delivered -> <code>needs-design</code> label removed -> dev notified</strong>
4. <strong>Dev decomposes work -> implements subtasks</strong>
5. <strong>Design QA -> fixes -> approval</strong>