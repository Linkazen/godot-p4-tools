# P4-Tools - Perforce Integration for Godot

A Godot 4.x editor plugin that provides seamless Perforce integration for game development workflows.

## Features

### Automatic Checkout
- **Auto-checkout before save**: Automatically checks out files before saving them (Ctrl+S)
- **Resource auto-checkout**: Handles .tres files, scenes, scripts, and other resources
- **Scene auto-checkout**: Checks out scenes when starting the game or making changes
- **Inspector integration**: Automatically checks out resources when editing properties

### Context Menu Integration
- **Right-click checkout**: Select files/folders in FileSystem dock and choose "P4 Checkout"
- **Single file precision**: Fixed to only checkout selected files, not entire folders
- **Directory support**: Can still checkout entire directories when needed

### Changelist Management
- **Dedicated changelist**: Creates "Checked out by Godot" changelist for organization
- **Auto-recreation**: Recreates changelist if deleted/reverted
- **Persistent tracking**: Maintains file checkout state across editor sessions

### Error Handling
- **Graceful failures**: Shows error messages when checkout fails
- **Validation**: Checks if files exist and are valid before operations
- **Recovery**: Handles cases where changelist is deleted or corrupted

## Installation

1. Copy the `p4-tools` folder to your project's `addons/` directory
2. Enable the plugin in Project Settings > Plugins
3. Ensure `p4` command is available in your system PATH
4. Make sure you're in a valid Perforce workspace

## Usage

### Automatic Mode
The plugin works automatically once enabled:
- Edit any resource in the inspector → auto-checkout
- Save any file (Ctrl+S) → auto-checkout before save
- Start the game → auto-checkout project.godot and main scene

### Manual Mode
Use the context menu for explicit operations:
1. Right-click files/folders in FileSystem dock
2. Select "P4 Checkout" from context menu
3. Files are checked out and moved to Godot changelist

### Tool Menu
Access additional functions from the toolbar:
- **P4 Checkout Current File**: Checkout the currently edited scene
- **P4 Show Checked Out Files**: Display status of files checked out this session

## Configuration

The plugin uses your existing Perforce configuration:
- Reads P4CONFIG, P4CLIENT, P4USER environment variables
- Uses your current workspace settings
- No additional configuration required

## Changelist Behavior

### "Checked out by Godot" Changelist
- Automatically created on first use
- All Godot checkouts are moved to this changelist
- Keeps your work organized and separate from manual checkouts
- Recreated automatically if deleted

### File Organization
- **Godot changelist**: Files checked out by the plugin
- **Default changelist**: Manual checkouts remain separate
- **Easy identification**: Clear separation of automatic vs manual changes

## Requirements

- Godot 4.x
- Perforce client (p4) installed and configured
- Valid Perforce workspace
- Files must be in the workspace path

## Troubleshooting

### "Failed to checkout" errors
- Verify p4 command is in PATH
- Check Perforce connection: `p4 info`
- Ensure files are in workspace
- Check file permissions

### Changelist issues
- Changelist recreated automatically if deleted
- Check P4 user permissions for changelist creation
- Verify workspace is properly configured

### Performance
- Plugin caches checkout status for performance
- Old entries cleaned up automatically every 10 minutes
- Minimal impact on editor responsiveness

## File Structure

```
addons/p4-tools/
├── README.md                           # This file
├── plugin.cfg                          # Plugin configuration
├── plugin.gd                          # Main plugin entry point
├── perforce_client.gd                 # Core Perforce operations
├── P4FileSystemContextMenuHandler.gd  # Context menu integration
├── P4ContextMenuItem.gd               # Context menu item class
└── P4Objects.gd                       # UI utility functions
```

## License

This plugin is part of the ZAMN project and follows the same licensing terms.

## Contributing

This plugin was developed for the ZAMN (Zombies Ate My Neighbors) project. Contributions and improvements are welcome.