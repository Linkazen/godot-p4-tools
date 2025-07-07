# P4 Tools - Godot Perforce Integration

A comprehensive Godot 4 plugin that provides seamless integration with Perforce (P4) version control system. This plugin automatically handles file checkout operations, provides a dedicated P4 interface, and streamlines version control workflow within the Godot editor.

![Godot P4 Tools](addons/p4-tools/assets/logo.png)

## Features

### 🔄 Automatic File Checkout
- **Smart Auto-Checkout**: Automatically checks out files when they're modified in the editor
- **Scene Detection**: Monitors scene changes and property edits through the inspector
- **Resource Tracking**: Handles checkout for scripts, scenes, and other resources before save
- **Project Run Integration**: Automatically checks out project.godot and main scene before running

### 📊 P4 Management Interface
- **Dedicated P4 Tab**: Integrated dock panel showing pending changelists and files
- **Changelist View**: Browse and manage your Perforce changelists directly in Godot
- **File Status Tracking**: View file status and actions within each changelist
- **Async Loading**: Non-blocking UI updates for better editor performance

### 🎯 Context Menu Integration
- **Right-Click Checkout**: Context menu option in File System dock for manual checkout
- **Multi-File Support**: Select and checkout multiple files at once
- **Smart File Detection**: Automatically detects file types and handles accordingly

### 🛠️ Advanced P4 Operations
- **Changelist Management**: Automatically creates and manages a dedicated "Godot" changelist
- **Workspace Detection**: Automatically detects P4 workspace root and client information
- **Batch Operations**: Efficient batch processing of multiple files
- **Error Handling**: Comprehensive error reporting and user feedback

## Installation

1. Download or clone this repository
2. Copy the `addons/p4-tools` folder to your project's `addons/` directory
3. Enable the plugin in Project Settings > Plugins > P4 Tools

## Prerequisites

- Godot 4.x
- Perforce client (p4) installed and configured
- Valid P4 workspace setup
- Network access to your Perforce server

## Usage

### Automatic Checkout
The plugin automatically monitors your editing activities and checks out files as needed:

- **Scene Editing**: When you modify scene properties or add/remove nodes
- **Script Editing**: When you save scripts or make changes
- **Resource Changes**: When you modify any resource files
- **Project Settings**: When you change project configuration

### Manual Operations
Use the Tools menu for manual operations:

- **Tools > P4 Checkout Current File**: Manually checkout the currently open scene
- **Tools > P4 Show Checked Out Files**: Display all files checked out this session

### P4 Interface
The P4 tab (located in the dock) provides:

- **Repository Info**: Shows current P4 client name and connection status
- **Changelist Browser**: View all pending changelists
- **File Explorer**: Browse files within each changelist
- **Status Indicators**: See file actions (edit, add, delete, etc.)

## Configuration

The plugin automatically configures itself by:

1. Detecting your P4 workspace root using `p4 info`
2. Creating a dedicated "Checked Out by Godot" changelist
3. Moving auto-checked-out files to this changelist for organization

## File Structure

```
addons/p4-tools/
├── plugin.cfg                           # Plugin configuration
├── plugin.gd                           # Main plugin entry point
├── perforce_client.gd                  # Core P4 client operations
├── p4_tab.gd                          # P4 interface tab
├── p4_tab.tscn                        # P4 tab UI layout
├── P4ContextMenuItem.gd               # Context menu item definition
├── P4FileSystemContextMenuHandler.gd  # Context menu integration
├── P4Objects.gd                       # Utility functions
└── assets/
    └── logo.png                       # Plugin logo
```

## Core Components

### PerforceClient (`perforce_client.gd`)
- Handles all P4 command execution
- Manages file checkout state and changelist operations
- Provides workspace detection and file path conversion
- Implements error handling and user feedback

### P4Tab (`p4_tab.gd`)
- Provides the main P4 interface in the editor dock
- Displays changelists and files in a tree view
- Handles async loading for better performance
- Integrates with editor themes for consistent styling

### Plugin Controller (`plugin.gd`)
- Manages plugin lifecycle and editor integration
- Connects to editor signals for automatic checkout
- Handles tool menu items and context menu integration
- Coordinates between different plugin components

## Technical Details

### Supported P4 Operations
- `p4 info` - Workspace detection
- `p4 edit` - File checkout
- `p4 add` - Add new files
- `p4 revert` - Revert changes
- `p4 changes` - List changelists
- `p4 describe` - Get changelist details
- `p4 where` - Path conversion
- `p4 change` - Changelist management

### Editor Integration Points
- **Resource Saving**: Intercepts save operations to ensure checkout
- **Scene Management**: Monitors scene changes and property edits
- **File System**: Integrates with File System dock context menu
- **Inspector**: Tracks property changes through undo/redo system
- **Project Runner**: Handles pre-run file checkout

## Troubleshooting

### Common Issues

**Plugin not detecting P4 workspace:**
- Ensure `p4` command is in your system PATH
- Verify P4 client is properly configured
- Check that you're working within a valid P4 workspace

**Files not being checked out automatically:**
- Verify the plugin is enabled in Project Settings
- Check that files are not already writable
- Look for error messages in the Output panel

**Context menu not appearing:**
- Restart Godot after enabling the plugin
- Check that you're right-clicking on files in the File System dock
- Verify the plugin loaded correctly (check for errors in the output)

### Debug Information
The plugin provides verbose logging to help diagnose issues:
- Check the Output panel for P4 command results
- Look for "P4:" prefixed messages for plugin-specific information
- Use "P4 Show Checked Out Files" to see current session state

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is open source. Please check the repository for specific license terms.

## Version History

- **v2.0.0**: Major rewrite with improved UI, async operations, and better P4 integration
- **v0.0.1**: Initial release with basic auto-checkout functionality

## Credits

Developed by **Quantum Tangent Games**

For more information about Godot plugin development, visit the [official Godot documentation](https://docs.godotengine.org/en/stable/tutorials/plugins/index.html).