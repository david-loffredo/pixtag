
Private Sub tbToolBar_ButtonClick(ByVal Button As MSComCtlLib.Button)
    On Error Resume Next
    Select Case Button.Key
        Case "New"
            'ToDo: Add 'New' button code.
            MsgBox "Add 'New' button code."
        Case "Open"
            mnuFileOpen_Click
        Case "Save"
            mnuFileSave_Click
        Case "Print"
            mnuFilePrint_Click
        Case "Cut"
            mnuEditCut_Click
        Case "Copy"
            mnuEditCopy_Click
        Case "Paste"
            mnuEditPaste_Click
        Case "Bold"
            'ToDo: Add 'Bold' button code.
            MsgBox "Add 'Bold' button code."
        Case "Italic"
            'ToDo: Add 'Italic' button code.
            MsgBox "Add 'Italic' button code."
        Case "Underline"
            'ToDo: Add 'Underline' button code.
            MsgBox "Add 'Underline' button code."
        Case "Align Left"
            'ToDo: Add 'Align Left' button code.
            MsgBox "Add 'Align Left' button code."
        Case "Center"
            'ToDo: Add 'Center' button code.
            MsgBox "Add 'Center' button code."
        Case "Align Right"
            'ToDo: Add 'Align Right' button code.
            MsgBox "Add 'Align Right' button code."
    End Select
End Sub




Public Sub RefreshContents()
    Dim xml_node As MSXML2.IXMLDOMNode
    Dim xml_nodes As MSXML2.IXMLDOMNodeList
    
    'On Error Resume Next
    status.Panels(1).Text = "Hello World"
    status.Panels
    
    

    ' Load the events
    Set xml_nodes = m_pixtag_doc.selectNodes(XML_FILETAG + "event")
    If Err.Number <> 0 Then
        status.Panels(1).Text = "No Events"
    End If

    For Each xml_node In xml_nodes
        EventSelect.AddItem (xml_node.Attributes.getNamedItem("id").nodeValue)
        EventSelect.Refresh
    Next
    
    
    ' Load the photos
    Set xml_nodes = m_pixtag_doc.selectNodes(XML_FILETAG + "photo")
    If Err.Number <> 0 Then
        status.Panels(1).Text = "No Photos"
    End If

    For Each xml_node In xml_nodes
        picker.AddItem (xml_node.Attributes.getNamedItem("file").nodeValue)
        picker.Refresh
    Next


End Sub
