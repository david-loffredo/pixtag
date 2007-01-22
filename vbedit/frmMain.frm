VERSION 5.00
Object = "{F9043C88-F6F2-101A-A3C9-08002B2F49FB}#1.2#0"; "comdlg32.ocx"
Object = "{831FDD16-0C5C-11D2-A9FC-0000F8754DA1}#2.0#0"; "MSCOMCTL.OCX"
Object = "{BDC217C8-ED16-11CD-956C-0000C04E4C0A}#1.1#0"; "TABCTL32.OCX"
Begin VB.Form frmMain 
   BorderStyle     =   3  'Fixed Dialog
   Caption         =   "PixTag note editor"
   ClientHeight    =   7275
   ClientLeft      =   150
   ClientTop       =   435
   ClientWidth     =   11880
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   NegotiateMenus  =   0   'False
   OLEDropMode     =   1  'Manual
   ScaleHeight     =   485
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   792
   ShowInTaskbar   =   0   'False
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton Command2 
      Caption         =   "Save Pixtag File"
      Height          =   375
      Left            =   5640
      TabIndex        =   2
      Top             =   6360
      Width           =   1455
   End
   Begin VB.CommandButton LoadNotes 
      Caption         =   "Load Pixtag File"
      Height          =   375
      Left            =   3840
      TabIndex        =   1
      Top             =   6360
      Width           =   1455
   End
   Begin MSComDlg.CommonDialog dlgCommonDialog 
      Left            =   7680
      Top             =   6240
      _ExtentX        =   847
      _ExtentY        =   847
      _Version        =   393216
   End
   Begin MSComctlLib.StatusBar status 
      Align           =   2  'Align Bottom
      Height          =   270
      Left            =   0
      TabIndex        =   0
      Top             =   7005
      Width           =   11880
      _ExtentX        =   20955
      _ExtentY        =   476
      _Version        =   393216
      BeginProperty Panels {8E3867A5-8586-11D1-B16A-00C0F0283628} 
         NumPanels       =   3
         BeginProperty Panel1 {8E3867AB-8586-11D1-B16A-00C0F0283628} 
            AutoSize        =   1
            Object.Width           =   15769
            Text            =   "Status"
            TextSave        =   "Status"
         EndProperty
         BeginProperty Panel2 {8E3867AB-8586-11D1-B16A-00C0F0283628} 
            Style           =   6
            AutoSize        =   2
            TextSave        =   "12/4/2006"
         EndProperty
         BeginProperty Panel3 {8E3867AB-8586-11D1-B16A-00C0F0283628} 
            Style           =   5
            AutoSize        =   2
            TextSave        =   "4:49 PM"
         EndProperty
      EndProperty
   End
   Begin TabDlg.SSTab tabs 
      Height          =   5895
      Left            =   90
      TabIndex        =   3
      Top             =   120
      Width           =   11655
      _ExtentX        =   20558
      _ExtentY        =   10398
      _Version        =   393216
      Tabs            =   5
      TabsPerRow      =   5
      TabHeight       =   529
      OLEDropMode     =   1
      TabCaption(0)   =   "Photo"
      TabPicture(0)   =   "frmMain.frx":0000
      Tab(0).ControlEnabled=   -1  'True
      Tab(0).Control(0)=   "PhotoFile"
      Tab(0).Control(0).Enabled=   0   'False
      Tab(0).Control(1)=   "img"
      Tab(0).Control(1).Enabled=   0   'False
      Tab(0).Control(2)=   "picker"
      Tab(0).Control(2).Enabled=   0   'False
      Tab(0).Control(3)=   "Frame1"
      Tab(0).Control(3).Enabled=   0   'False
      Tab(0).Control(4)=   "EventFrame"
      Tab(0).Control(4).Enabled=   0   'False
      Tab(0).Control(5)=   "File1"
      Tab(0).Control(5).Enabled=   0   'False
      Tab(0).ControlCount=   6
      TabCaption(1)   =   "Event"
      TabPicture(1)   =   "frmMain.frx":001C
      Tab(1).ControlEnabled=   0   'False
      Tab(1).ControlCount=   0
      TabCaption(2)   =   "Select"
      TabPicture(2)   =   "frmMain.frx":0038
      Tab(2).ControlEnabled=   0   'False
      Tab(2).Control(0)=   "Option3"
      Tab(2).Control(1)=   "Option2"
      Tab(2).Control(2)=   "Option1"
      Tab(2).ControlCount=   3
      TabCaption(3)   =   "Import Files"
      TabPicture(3)   =   "frmMain.frx":0054
      Tab(3).ControlEnabled=   0   'False
      Tab(3).ControlCount=   0
      TabCaption(4)   =   "Preferences"
      TabPicture(4)   =   "frmMain.frx":0070
      Tab(4).ControlEnabled=   0   'False
      Tab(4).Control(0)=   "PixtagFilename"
      Tab(4).Control(1)=   "Label1"
      Tab(4).Control(2)=   "Label2"
      Tab(4).ControlCount=   3
      Begin VB.FileListBox File1 
         Height          =   2235
         Left            =   2280
         TabIndex        =   19
         Top             =   360
         Width           =   2895
      End
      Begin VB.OptionButton Option3 
         Caption         =   "By Event"
         Height          =   375
         Left            =   -73920
         TabIndex        =   18
         Top             =   2400
         Width           =   2775
      End
      Begin VB.OptionButton Option2 
         Caption         =   "By Date"
         Height          =   375
         Left            =   -73920
         TabIndex        =   17
         Top             =   1680
         Width           =   2775
      End
      Begin VB.OptionButton Option1 
         Caption         =   "All Photos"
         Height          =   375
         Left            =   -73920
         TabIndex        =   16
         Top             =   840
         Width           =   2775
      End
      Begin VB.Frame EventFrame 
         Caption         =   "Photo Events"
         Height          =   2415
         Left            =   2520
         TabIndex        =   8
         Top             =   2880
         Width           =   5415
         Begin VB.CommandButton RemoveEvent 
            Caption         =   "Remove Event"
            Enabled         =   0   'False
            Height          =   375
            Left            =   2880
            TabIndex        =   12
            Top             =   1920
            Width           =   2175
         End
         Begin VB.CommandButton AddEvent 
            Caption         =   "Add Event"
            Enabled         =   0   'False
            Height          =   375
            Left            =   360
            TabIndex        =   11
            Top             =   1920
            Width           =   2175
         End
         Begin VB.ComboBox EventSelect 
            Height          =   315
            Left            =   240
            TabIndex        =   10
            Text            =   "Select An Event To Add"
            Top             =   1440
            Width           =   5055
         End
         Begin VB.ListBox EventList 
            Height          =   1035
            Left            =   120
            TabIndex        =   9
            Top             =   240
            Width           =   5175
         End
      End
      Begin VB.Frame Frame1 
         Caption         =   "Photo Description"
         Height          =   1455
         Left            =   2520
         TabIndex        =   6
         Top             =   1320
         Width           =   5415
         Begin VB.TextBox PhotoDesc 
            Height          =   975
            Left            =   120
            MultiLine       =   -1  'True
            TabIndex        =   7
            Text            =   "frmMain.frx":008C
            Top             =   360
            Width           =   5175
         End
      End
      Begin VB.TextBox PixtagFilename 
         Height          =   285
         Left            =   -73560
         TabIndex        =   5
         Text            =   "Text1"
         Top             =   1545
         Width           =   6135
      End
      Begin VB.ListBox picker 
         Height          =   5130
         Left            =   120
         TabIndex        =   4
         Top             =   600
         Width           =   2295
      End
      Begin VB.Image img 
         Height          =   4575
         Left            =   8280
         Stretch         =   -1  'True
         Top             =   720
         Width           =   3135
      End
      Begin VB.Label PhotoFile 
         Caption         =   "File:"
         Height          =   255
         Left            =   2640
         TabIndex        =   15
         Top             =   720
         Width           =   4095
      End
      Begin VB.Label Label1 
         Caption         =   "The pixtag file is where the photo annotations are kept.   Change this to select a new photo database to edit."
         Height          =   615
         Left            =   -74760
         TabIndex        =   14
         Top             =   600
         Width           =   5655
      End
      Begin VB.Label Label2 
         Caption         =   "Pixtag File:"
         Height          =   255
         Left            =   -74760
         TabIndex        =   13
         Top             =   1560
         Width           =   1095
      End
   End
End
Attribute VB_Name = "frmMain"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private Declare Function OSWinHelp% Lib "user32" Alias "WinHelpA" (ByVal hwnd&, ByVal HelpFile$, ByVal wCommand%, dwData As Any)

' disable the ceb namespace option by putting the following
' tag in the config file <ceb:option no-ns="true"/>
Const XML_FILETAG               As String = "/pixtag/"
Const XML_SOAPTAG               As String = "//"

Dim m_pixtag_doc                As MSXML2.DOMDocument

Public Function StripNewlines(s As String) As String
    s = Replace(s, Chr(10), " ")
    s = Replace(s, Chr(13), " ")
    s = Replace(s, "  ", " ")
    StripNewlines = s
End Function


Public Function LoadPixtagFile() As Boolean
    LoadPixtagFile = False
    status.Panels(1).Text = "Loading " & PixtagFilename.Text
        
    Dim xml_doc As New MSXML2.DOMDocument
    If Not xml_doc.Load(PixtagFilename.Text) Then
        tabs.Tab = 4
        MsgBox "Problems Loading Pixtag File", , "Load Error"
        Exit Function
    End If
    
    'On Error Resume Next
    'reset_control
    
    Set m_pixtag_doc = xml_doc
    RefreshContents
    
    status.Panels(1).Text = "Loaded " & PixtagFilename.Text
    
    LoadPixtagFile = True
End Function

Public Sub RefreshContents()
    Dim xml_node As MSXML2.IXMLDOMNode
    Dim xml_nodes As MSXML2.IXMLDOMNodeList
    Dim tag As String
    Dim title As String
    Dim entry As String
        
    'On Error Resume Next

    ' Load the event list
    EventSelect.Clear
    Set xml_nodes = m_pixtag_doc.selectNodes(XML_FILETAG & "event")
    If Err.Number <> 0 Then
        status.Panels(1).Text = "No Events"
    End If

    For Each xml_node In xml_nodes
        tag = xml_node.Attributes.getNamedItem("id").nodeValue
        title = xml_node.selectSingleNode("title").Text
        entry = tag
        entry = entry + " - "
        entry = entry + title
        
        EventSelect.AddItem (entry)
    Next
    EventSelect.Refresh
       
    ' Load the photo picker list
    Set xml_nodes = m_pixtag_doc.selectNodes(XML_FILETAG & "photo")
    If Err.Number <> 0 Then
        status.Panels(1).Text = "No Photos"
    End If

    For Each xml_node In xml_nodes
        picker.AddItem (xml_node.Attributes.getNamedItem("file").nodeValue)
    Next
    picker.Refresh

End Sub

Public Sub LoadPhoto(file As String)
    ' Load the photos
    Dim xml_node As MSXML2.IXMLDOMNode
    Dim s As String
    
    PhotoDesc.Text = ""
    EventList.Clear
    
    Set xml_node = FindPhoto(file)
    If xml_node Is Nothing Then
        status.Panels(1).Text = "No such photo"
        Exit Sub
    End If
    
    On Error Resume Next
    PhotoDesc.Text = StripNewlines(xml_node.selectSingleNode("desc").Text)
    EventList.AddItem ("random event")
        
End Sub

Public Function FindPhoto(file As String) As MSXML2.IXMLDOMNode
    Dim xml_node As MSXML2.IXMLDOMNode
     
    Set FindPhoto = Nothing
    Set xml_nodes = m_pixtag_doc.selectNodes(XML_FILETAG + "photo")
    If Err.Number <> 0 Then
        Exit Function
    End If

    For Each xml_node In xml_nodes
        If (xml_node.Attributes.getNamedItem("file").nodeValue = file) Then
                Set FindPhoto = xml_node
                Exit Function
        End If
    Next
End Function


Private Sub Command2_Click()
    status.Panels(1).Text = "Hello World"
End Sub

Private Sub Form_Load()
    LoadResStrings Me
    'Me.Left = GetSetting(App.title, "Settings", "MainLeft", 1000)
    'Me.Top = GetSetting(App.title, "Settings", "MainTop", 1000)
    'Me.Width = GetSetting(App.title, "Settings", "MainWidth", 6500)
    'Me.Height = GetSetting(App.title, "Settings", "MainHeight", 6500)
    Me.PixtagFilename.Text = GetSetting(App.title, "Settings", _
        "DefaultPixtagFile", "select filename")
        
        img.Picture = LoadPicture("\dave\pictures\ISS006-E-30141.JPG")
    File1.Pattern = "*.frm"
 
End Sub


Private Sub Form_OLEDragDrop(Data As DataObject, Effect As Long, Button As Integer, Shift As Integer, X As Single, Y As Single)
   'MsgBox ("ole drag and drop" + Data.Files.Item(1))
   ' (Data.Files.Item(1))
End Sub

Private Sub Form_Unload(Cancel As Integer)
    Dim i As Integer


    'close all sub forms
    For i = Forms.Count - 1 To 1 Step -1
        Unload Forms(i)
    Next
    If Me.WindowState <> vbMinimized Then
        SaveSetting App.title, "Settings", "MainLeft", Me.Left
        SaveSetting App.title, "Settings", "MainTop", Me.Top
        SaveSetting App.title, "Settings", "MainWidth", Me.Width
        SaveSetting App.title, "Settings", "MainHeight", Me.Height
        SaveSetting App.title, "Settings", "DefaultPixtagFile", _
                Me.PixtagFilename.Text
    End If
End Sub


Private Sub LoadNotes_Click()
    LoadPixtagFile
    
End Sub

Private Sub picker_Click()
       LoadPhoto (picker.Text)
End Sub
