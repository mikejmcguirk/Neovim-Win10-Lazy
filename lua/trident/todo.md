## WHY

- I have to write a lot of hacks around harpoon to make it work in my config
- Harpoon has a long startup time
- I do not love harpoon's extensions and events system

## DESIGN GOALS

- Configure with g:vars
- Use autocmds to drive events
  * Should not need to worry though about pushing too much data in the autocmds about the events themselves, as trident should have an API that allows everything to be accessed
- Build the functionality out of composable, exposed pieces. So like, you should not need to create your own function to remove an item from the current list

## IDEAS

- Should be a callback for jumping to the last position, this way, you could customize it to check for the " mark, and fallback to trident's position if it's not there
