// 添加分发按钮到资源*表格*的每一项，并显示同步状态。
// =======================================
//
// 只在cloud开启该分发按钮
//
// =======================================
// ### 使用方法 ###
//
// 在table加上属性model_name，以及在各tr的首个td里加上uuid和name两个属性。
//
// %table.{model_name: :App}
//   %tr
//     %th.span5 UUID
//     %th.span3= t "App.name"
//     ...
//   - @apps.each_with_index do |app, idx|
//     %tr
//       %td{uuid: app.uuid, name: app.name}= app.uuid
//       ...
//
// TODO 载入resque是否正常服务
// TODO 加入验证用户
//
$(document).ready(function() {

  var table = $("table[model_name]");
  if (table.length === 0) { return false; } // 如果没有配置
  if (table.length >= 2) { alert("目前distribute_tree.js只支持单页同步一种资源类型"); return false; }
  var table_model_name = table.attr('model_name');

  // Constant definement
  var api_prefix = "/distribute_tree";

  // 只有管理员才能同步学校
  // TODO optimize
  if (!$(".navbar ul.nav.pull-right li a").text().match(/陈大伟/) && (table_model_name === 'School')) { return false; }

  // 1. 初始化页面元素
  //
  // 1.1 th 分发按钮
  table.find('tr:first').append(
    $("<th>").addClass("pointer span1").html(
      $("<span>").addClass("icon icon-th")
    )
  // 并绑定 选择学校列表 弹框
  ).on('click', 'th:last', function(event) {
    var uuids = _.map(trs.find('td:last input:checked'), function(input) { return $(input).attr('uuid'); });
    if (uuids.length === 0) { alert("请选择至少一个资源用于同步"); event.preventDefault(); return false; }
    var modal_html = function() { return distribute_to_schools_modal.find('.modal'); };

    function show() {
      // 统计显示勾选的资源数目
      modal_html().find('.modal-header h4.title span.count').html(uuids.length);
      modal_html().modal('show');
    }

    // 判断是否ajax载入学校列表
    if (_.isEmpty($("#distribute_to_schools_modal").html())) {
      $.get(api_prefix + "/distribute/servers.html", function(html) {
        distribute_to_schools_modal.html(html);

        // 2. 绑定**提交事件**
        distribute_to_schools_modal.on('click', 'button.submit', function() {
          var school_uuids = _.map(distribute_to_schools_modal.find('table tr:gt(0) td input:checked'), function(input) { return $(input).attr('id'); });
          if (school_uuids.length === 0) { alert("请选择至少一个学校用于同步"); event.preventDefault(); return false; }

          // 2.1 处理元素显示
          var btn = distribute_to_schools_modal.find(".modal-footer button.save-button");
          btn.button('loading');

          // 2.2 ajax提交数据
          var data = {
            model_name: table_model_name,
            uuids: uuids,
            school_uuids: school_uuids
          };
          // 2.3 服务器状态返回
          $.post(api_prefix + '/distribute', data, function(e) {
            var alert_html = modal_html().find(".alert");
            alert_html.find('div.alert').removeClass('alert-success').removeClass('alert-error').addClass('alert-' + e.status);
            alert_html.find('#flash_notice span.status').html('已经同步' + uuids.length + '个资源到' + school_uuids.length + '个服务器。');
            $(".container.content").prepend(alert_html);
          }).always(function(e) {
            modal_html().modal('hide');
            btn.button('reset');
          });
        });
    // 并浮现
        show();
      });
    } else {
      show();
    }
  });
  // 1.2 td 是否分发该资源
  var trs = table.find('tr:gt(0)');
  var is_defined_uuid_and_name_attrs = false; // check setup
  _.each(trs, function(_tr) {
    var tr = $(_tr);
    var td_first = tr.find('td[uuid]');
    if (td_first.length !== 0) { is_defined_uuid_and_name_attrs = true; }
    tr.append(
      $("<td>").append(
        $("<input>").attr("type", "checkbox")
                    .attr('uuid', td_first.attr('uuid'))
                    .attr('name', td_first.attr('name'))
      )
    );
  });
  if (!is_defined_uuid_and_name_attrs) {
    alert("没有定义在每行记录定义uuid和name，请察看distribute_tree.js的文档。");
    event.preventDefault(); return false;
  }
  // 1.3 放置一个 学校列表容器
  var distribute_to_schools_modal = $("body").append(
    $("<div>").attr("id", "distribute_to_schools_modal")
  ).find('#distribute_to_schools_modal');

  // 1.4 载入各个资源的同步状态
  var params = {model_name: table_model_name, uuids: _.map(trs.find('td:last input'), function(input) { return $(input).attr('uuid'); })};
  $.get(api_prefix + "/distribute.json", params, function(result) {
    _.each(trs, function(_tr) {
      var td_last = $(_tr).find('td:last');
      var urls    = result.data[td_last.find('input[type=checkbox]').attr('uuid')];
      // 如果存在*没有分发完成*的记录
      if (urls) {
        td_last.append($("<div>").addClass('pointer server_urls').text(urls.length))
               .append($("<div>").addClass('hide server_urls count').text(urls.join(', ')));
      }
    });
    // 显示具体分发地址
    trs.on('click', 'td:last .server_urls', function(e) {
      $(e.target).closest('td').find('.server_urls.count').toggle();
    });
  });

});
