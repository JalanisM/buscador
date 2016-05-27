function es_correo(email) {
    var regex = /^([a-zA-Z0-9_.+-])+\@(([a-zA-Z0-9-])+\.)+([a-zA-Z0-9]{2,4})+$/;
    return regex.test(email);
}

$(document).ready(function(){
    $('#comentario_submit').click(function(){
        if ($('#comentario_correo').val() != undefined && $('#comentario_correo').val() == '')
        {
            $('#error_mensaje').empty().html('El correo no puede ser vacio.');
            return false;
        } else if ($('#comentario_correo').val() != undefined){
            if (!es_correo($('#comentario_correo').val()))
            {
                $('#error_mensaje').empty().html('El correo no es válido, por favor verifica.');
                return false;
            }
        }
        if ($('#comentario_nombre').val() != undefined && $('#comentario_nombre').val() == '')
        {
            $('#error_mensaje').empty().html('El nombre no puede ser vacio.');
            return false;
        }
        if ($('#comentario_comentario').val() == '')
        {
            $('#error_mensaje').empty().html('El comentario no puede ser vacio.');
            return false;
        }
    });

    $(document).on('change', "[id^='resuelto_']", function()
    {
        var comentario_id = $(this).attr('id').split("_")[1];

        // Cambiamos el valor del checkbox de acuerdo a lo que escogio
        $(this).val($(this).val() == "1" ? "0" : "1");

        $.ajax({
            url: "/comentarios/" + comentario_id + "/update_admin",
            type: 'POST',
            data: {resuelto: $(this).val()}

        }).done(function(html) {

            if (html == '1')
            {
                // Quiere decir que cambio a resuelto=1
                if ($('#resuelto_'+comentario_id).val() == '1')
                {
                    $('#span_resuelto_' + comentario_id).removeClass('glyphicon-alert').addClass('glyphicon-ok');
                    $('#span_resuelto_' + comentario_id).css('color','#889b45');
                } else {
                    $('#span_resuelto_' + comentario_id).removeClass('glyphicon-ok').addClass('glyphicon-alert');
                    $('#span_resuelto_' + comentario_id).css('color','#ea9028');
                }
            }

        });
    });
});
