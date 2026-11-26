module Api
  module V1
    # JSON representation of comments as a tree (see docs/api-design.md §3):
    # every comment is a CommentSerializer plus `replies`, an array with the same
    # shape (empty if it has no replies).
    #
    # It receives a flat list with all the comments of the tree, so it makes no
    # queries of its own. Siblings keep the order of that list: the caller sorts
    # it. It is not recursive, so a very deep conversation cannot overflow the
    # stack here.
    class CommentTreeSerializer
      def initialize(comments)
        @comments = comments
      end

      # The comments whose parent is not in the list (the top-level ones, for the
      # comments of a submission), each one with its replies nested.
      def as_json(*)
        nodes = @comments.to_h do |comment|
          [ comment.id, CommentSerializer.new(comment).as_json.merge(replies: []) ]
        end
        # The hash keeps the order of the list.
        roots = []
        nodes.each_value do |node|
          parent = nodes[node[:parent_id]]
          (parent ? parent[:replies] : roots) << node
        end
        roots
      end
    end
  end
end
