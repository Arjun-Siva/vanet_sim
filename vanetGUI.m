classdef vanetGUI < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure              matlab.ui.Figure
        CompareDropDownLabel  matlab.ui.control.Label
        CompareDropDown       matlab.ui.control.DropDown
        Value1EditFieldLabel  matlab.ui.control.Label
        Value1EditField       matlab.ui.control.NumericEditField
        Value2EditFieldLabel  matlab.ui.control.Label
        Value2EditField       matlab.ui.control.NumericEditField
        Value3EditFieldLabel  matlab.ui.control.Label
        Value3EditField       matlab.ui.control.NumericEditField
        SimulateButton        matlab.ui.control.StateButton
        Label                 matlab.ui.control.Label
        StopButton            matlab.ui.control.Button
        UIAxes                matlab.ui.control.UIAxes
    end

   
    methods (Access = public)
        
        function results = vanet(app,nodes,range,protocol)
            import Packet;
            import Node;
            
            current_slot = 1;
            round = 1;
            dataPackAt = 1;
            n = numel(nodes);
            for i = 1:n
                nodes(i).range = range;
            end
            
            nodes = arrayfun( @(x) x.findRelayId(nodes), nodes);
            
            while dataPackAt ~= n
                for i = 1:n
                    nodes = nodes(i).acquireSlot(current_slot,nodes);
                end
                
                for i = 1:n
                    nodes = nodes(i).sendPackets(nodes,current_slot);
                end
                nodes = arrayfun( @(x) x.processPacket(current_slot), nodes);
                %nodes = arrayfun( @(x) x.incrementx(), nodes);
                datapack = [];
                for i = 1:numel(dataPackAt)
                    if dataPackAt(i) ~= 0
                        [datapackIds, nodes] = nodes(dataPackAt(i)).sendData(nodes,current_slot,protocol);
                    end
                    for j = 1:numel(datapackIds)
                        if datapackIds(j) ~= 0
                            datapack = [datapack;datapackIds];
                        end
                    end
                end
                uniq = unique(datapack);
                dataPackAt = uniq(end);
                try
                    dataPackAt = [dataPackAt;uniq(numel(uniq)-1)];
                catch
                end
                
                %disp(dataPackAt);
                if current_slot == 60
                    current_slot = 1;
                    disp("Frame "+round+" over");
                    round = round + 1;
                    disp("Datapack at:"+ dataPackAt);
                    hold(app.UIAxes,'on');
                    plot(app.UIAxes,[nodes.x]',[nodes.y]',"r>");
                    try
                        plot(app.UIAxes,[nodes(dataPackAt(1)).x; nodes(nodes(dataPackAt(1)).relayId).x], [nodes(dataPackAt(1)).y; nodes(nodes(dataPackAt(1)).relayId).y], "->b", "MarkerFaceColor","b");
                    catch
                    end
                    text(app.UIAxes,500,12.5, "Frame:"+round+","+protocol+" protocol, No.of nodes:"+n+",range:"+range);
                    try
                        plot(app.UIAxes,[nodes(dataPackAt(2)).x; nodes(nodes(dataPackAt(2)).relayId).x], [nodes(dataPackAt(2)).y; nodes(nodes(dataPackAt(2)).relayId).y], "->b", "MarkerFaceColor","b");
                    catch
                    end
                    hold(app.UIAxes,'off');
                    pause(0.001);
                else
                    current_slot = current_slot + 1;
                end
                cla(app.UIAxes);
            end
                results = round;
                
        end
        
        function avg = getAverage(~,r)
            num_of_nodes_transmitted = 0;
            avg_sum = 0;
            for i = 1:numel(r)
                if r(i) ~= 0
                    num_of_nodes_transmitted = num_of_nodes_transmitted + 1;
                    avg_sum = avg_sum + (1 / r(i));
                end
            end
            avg = avg_sum/num_of_nodes_transmitted;
        end
        
        function nodes = createNodes(~, vehdensity)
            import Packet;
            import Node;
            
            xmin= 0;
            xmax= 2000;
            n = 2*vehdensity;
            x_s = xmin+rand(1,n)*(xmax-xmin);
            x_s = sort(x_s);
            y_s = [5;10;15;20];
            nodes(n,1) = Node();
            
            for i = 1:n
                nodes(i).id = i;
                nodes(i).x = x_s(i);
                nodes(i).y = y_s(randi([1 4]));
                nodes(i).packetToSend = Packet(nodes(i));
                nodes(i).acquiredSlot = randi([1 60]);
                nodes(i).frameInfo(nodes(i).acquiredSlot) = i;
            end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Callback function
        function getComparisonVal(app, event)
          
        end

        % Drop down opening function: CompareDropDown
        function getDropDownVal(app, event)
           
        end

        % Value changed function: SimulateButton
        function SimulateButtonValueChanged(app, event)
            value = app.SimulateButton.Value;
            if value == 1
                if app.CompareDropDown.Value == "Density"
                    nodes1 = app.createNodes(app.Value1EditField.Value);
                    nodes2 = app.createNodes(app.Value2EditField.Value);
                    nodes3 = app.createNodes(app.Value3EditField.Value);
                    r1 = app.vanet(nodes1,300,"vemac");
                    r11 = app.vanet(nodes1,300,"cahmac");
                    r111 = app.vanet(nodes1,300,"ocamac");
                    r2 = app.vanet(nodes2,300,"vemac");
                    r22 = app.vanet(nodes2,300,"cahmac");
                    r222 = app.vanet(nodes2,300,"ocamac");
                    r3 = app.vanet(nodes3,300,"vemac");
                    r33 = app.vanet(nodes3,300,"cahmac");
                    r333 = app.vanet(nodes3,300,"ocamac");
                   
                elseif app.CompareDropDown.Value == "Range"
                    nodes = app.createNodes(50);
                    r1 = app.vanet(nodes,app.Value1EditField.Value,"vemac");
                    r11 = app.vanet(nodes,app.Value1EditField.Value,"cahmac");
                    r111 = app.vanet(nodes,app.Value1EditField.Value,"ocamac");
                    r2 = app.vanet(nodes,app.Value2EditField.Value,"vemac");
                    r22 = app.vanet(nodes,app.Value2EditField.Value,"cahmac");
                    r222 = app.vanet(nodes,app.Value2EditField.Value,"ocamac");
                    r3 = app.vanet(nodes,app.Value3EditField.Value,"vemac");
                    r33 = app.vanet(nodes,app.Value3EditField.Value,"cahmac");
                    r333 = app.vanet(nodes,app.Value3EditField.Value,"ocamac");
                end
                rvanet = [r1;r2;r3];
                rcahmac = [r11;r22;r33];
                rocamac = [r111;r222;r333];
                rcombined = [rvanet(:),rcahmac(:),rocamac(:)];
                h = bar([app.Value1EditField.Value,app.Value2EditField.Value,app.Value3EditField.Value],rcombined,"grouped");
                set(h, {'DisplayName'}, {'VeMac','Cah-Mac','Oca-Mac'}')
                % Legend will show names for each color
                legend()
            end
        end

        % Button pushed function: StopButton
        function StopButtonPushed(app, event)
            exit()
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'MATLAB App';

            % Create CompareDropDownLabel
            app.CompareDropDownLabel = uilabel(app.UIFigure);
            app.CompareDropDownLabel.HorizontalAlignment = 'right';
            app.CompareDropDownLabel.Position = [499 431 50 22];
            app.CompareDropDownLabel.Text = 'Compare';

            % Create CompareDropDown
            app.CompareDropDown = uidropdown(app.UIFigure);
            app.CompareDropDown.Items = {'Density', 'Range'};
            app.CompareDropDown.DropDownOpeningFcn = createCallbackFcn(app, @getDropDownVal, true);
            app.CompareDropDown.Position = [557 431 77 18];
            app.CompareDropDown.Value = 'Density';

            % Create Value1EditFieldLabel
            app.Value1EditFieldLabel = uilabel(app.UIFigure);
            app.Value1EditFieldLabel.HorizontalAlignment = 'right';
            app.Value1EditFieldLabel.Position = [518 375 45 22];
            app.Value1EditFieldLabel.Text = 'Value 1';

            % Create Value1EditField
            app.Value1EditField = uieditfield(app.UIFigure, 'numeric');
            app.Value1EditField.Position = [578 374 37 24];

            % Create Value2EditFieldLabel
            app.Value2EditFieldLabel = uilabel(app.UIFigure);
            app.Value2EditFieldLabel.HorizontalAlignment = 'right';
            app.Value2EditFieldLabel.Position = [517 341 45 22];
            app.Value2EditFieldLabel.Text = 'Value 2';

            % Create Value2EditField
            app.Value2EditField = uieditfield(app.UIFigure, 'numeric');
            app.Value2EditField.Position = [577 340 39 24];

            % Create Value3EditFieldLabel
            app.Value3EditFieldLabel = uilabel(app.UIFigure);
            app.Value3EditFieldLabel.HorizontalAlignment = 'right';
            app.Value3EditFieldLabel.Position = [518 303 45 22];
            app.Value3EditFieldLabel.Text = 'Value 3';

            % Create Value3EditField
            app.Value3EditField = uieditfield(app.UIFigure, 'numeric');
            app.Value3EditField.Position = [578 302 37 24];

            % Create SimulateButton
            app.SimulateButton = uibutton(app.UIFigure, 'state');
            app.SimulateButton.ValueChangedFcn = createCallbackFcn(app, @SimulateButtonValueChanged, true);
            app.SimulateButton.Text = 'Simulate';
            app.SimulateButton.Position = [507 235 122 34];

            % Create Label
            app.Label = uilabel(app.UIFigure);
            app.Label.Position = [65 45 534 22];
            app.Label.Text = 'Note: The relative positions of the vehicles are assumed to stay intact during the observing period';

            % Create StopButton
            app.StopButton = uibutton(app.UIFigure, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.Position = [507 179 122 31];
            app.StopButton.Text = 'Stop';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'Relative positions of vehicles')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.Position = [1 66 491 400];

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = vanetGUI

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end