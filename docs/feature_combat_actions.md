# User Story:

As a player, when I select an active combatant that has not used an action (stride, consumable, or ability), I want to see a menu of their 4 slotted abilities and their consumable item so I can make tactical decisions.

## Requirements:

* Stride: Always available, no cost, works as it does right now. can't move through enemy squares normally, and can't end on enemy or ally combatant squares.
* Consumable: Free to use but depletes the item; greyed out as "consumable icon - placeholder art - can use godot icon" if no item is equipped or was already consumed.
* Activate Ability: Costs Energy; greyed out if the unit's current Energy is less than the cost.
* UI Components:
* A "Radial" or "Pop-up" menu that appears upon clicking a player unit.
* 4 buttons for slotted actions (maximum 4).
* 1 dedicated button for the equipped Consumable. (this button code by in the center, with the action buttons surrounding the center consumable button - see image. tv remote but center button is a bit smaller than in the picture, radial buttons as large as needed)
* Tooltips that display the Name, Description, and Energy Cost upon hovering.
* Please be sure to define the following variables  

- Name: Display name (e.g., "Fireball").
- ID: String identifier for logic (e.g., fire_01).
- Tags: (Melee, Ranged, Magic, Utility).
- Energy Cost: Int value subtracted from unit's pool.
- Range: Int (number of tiles).
- Target Type: Enum (Self, Single Enemy, Single Ally, AoE, Cone).
- Description: Flavor text for tooltips.
Feel free to populate these values with random ranges, maybe make up 7-8 as placeholders and equip to different placeholder combatants. Also randomized with everything else when you hit the random new fight button we currently have. Same with the consumable - doesn't even need to anything yet. 

Please account for the following while building:
- I plan to provide a csv with all the different actions in the future. It will certainly come with more fields/values for the abilities later down the road
- After this new feature, we will move on to building functional actions, like slashing attacks person in front of you, flame breath is a cone attack, teleport, sprint, etc. and after that we will build new QTEs for each. 